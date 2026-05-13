import Foundation
import Combine
import Supabase

@MainActor
final class TodoViewModel: ObservableObject {
    // ── State ────────────────────────────────────────────────
    @Published var items: [TodoItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var rolloverItems: [TodoItem] = []
    @Published var showRollover = false

    private let service   = TodoService.shared
    private let notifs    = NotificationService.shared
    private var realtimeChannel: RealtimeChannelV2?

    var userId: UUID?

    // ── Bootstrap ────────────────────────────────────────────

    func bootstrap(userId: UUID) async {
        self.userId = userId
        await fetchAll(userId: userId)
        await spawnRecurringItems()
        await checkRollover()
        subscribeRealtime(userId: userId)
        notifs.scheduleDailyReminder()
    }

    // ── Fetch ────────────────────────────────────────────────

    func fetchAll(userId: UUID) async {
        isLoading = true
        do {
            let start = DateUtils.adding(days: -30, to: DateUtils.today())
            let end = DateUtils.adding(days: 60, to: DateUtils.today())
            items = try await service.fetch(userId: userId, from: start, to: end)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // ── Items for a date ─────────────────────────────────────

    func items(for date: String) -> [TodoItem] {
        items.filter { $0.listDate == date }
    }

    func pending(for date: String) -> [TodoItem] {
        items(for: date).filter { $0.status == .pending }
    }

    func completed(for date: String) -> [TodoItem] {
        items(for: date).filter { $0.status == .done }
    }

    func obe(for date: String) -> [TodoItem] {
        items(for: date).filter { $0.status == .obe }
    }

    // ── All unique list dates (for history) ──────────────────

    var allListDates: [String] {
        Array(Set(items.map { $0.listDate }))
            .sorted(by: >)
    }

    // ── Add ──────────────────────────────────────────────────

    func addItem(
        title: String,
        notes: String?,
        listDate: String,
        deadline: Date?,
        reminderOffset: Int?,
        recurrence: Recurrence,
        priority: Priority = .medium,
        recurrenceEndDate: String? = nil
    ) async {
        guard let userId else { return }
        var item = TodoItem.create(
            userId: userId,
            title: title,
            notes: notes,
            listDate: listDate,
            deadline: deadline,
            reminderOffset: reminderOffset,
            recurrence: recurrence,
            priority: priority
        )
        item.recurrenceEndDate = recurrenceEndDate
        do {
            let saved = try await service.insert(item)
            await MainActor.run {
                items.append(saved)
            }
            notifs.scheduleReminder(for: saved)
            
            // Immediately spawn future occurrences if recurring
            if recurrence != .once {
                await spawnRecurringItems()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Update ───────────────────────────────────────────────

    func updateItem(_ item: TodoItem) async {
        do {
            let updated = try await service.update(item)
            apply(updated)
            notifs.cancelReminder(for: item.id)
            notifs.scheduleReminder(for: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Complete ─────────────────────────────────────────────

    func complete(_ item: TodoItem) async {
        var updated = item
        updated.status = .done
        updated.completedAt = Date()
        await updateItem(updated)
    }

    // ── Mark OBE ─────────────────────────────────────────────

    func markOBE(_ item: TodoItem) async {
        var updated = item
        updated.status = .obe
        await updateItem(updated)
    }

    // ── Move to date ─────────────────────────────────────────

    func move(_ item: TodoItem, to date: String) async {
        // Mark the original as moved
        var original = item
        original.status = .done
        original.movedToDate = date
        original.completedAt = Date()
        await updateItem(original)
        
        // Create a fresh copy on the new date
        guard let userId else { return }
        var newItem = TodoItem.create(
            userId: userId,
            title: item.title,
            notes: item.notes,
            listDate: date,
            deadline: item.deadline,
            reminderOffset: item.reminderOffset,
            recurrence: item.recurrence,
            priority: item.priority
        )
        newItem.templateId = item.templateId
        newItem.recurrenceEndDate = item.recurrenceEndDate
        
        do {
            let saved = try await service.insert(newItem)
            await MainActor.run {
                items.append(saved)
            }
            notifs.scheduleReminder(for: saved)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Undo (revert to pending) ─────────────────────────────

    func revertToPending(_ item: TodoItem) async {
        var updated = item
        updated.status = .pending
        updated.completedAt = nil
        await updateItem(updated)
    }

    // ── Delete ───────────────────────────────────────────────

    func delete(_ item: TodoItem) async {
        await MainActor.run {
            items.removeAll { $0.id == item.id }
        }
        do {
            try await service.delete(id: item.id)
            notifs.cancelReminder(for: item.id)
        } catch {
            await MainActor.run {
                items.append(item)
                self.error = error.localizedDescription
            }
        }
    }

    func deleteSeries(_ item: TodoItem) async {
        // If this item is a spawned copy, templateId points to the original
        // If this item IS the original template, its own id is the templateId
        let templateId = item.templateId ?? item.id
        
        do {
            try await service.deleteSeries(templateId: templateId)
            await MainActor.run {
                items.removeAll { itemInList in
                    itemInList.id == templateId ||           // the template itself
                    itemInList.templateId == templateId ||   // spawned copies
                    itemInList.id == item.id                 // the item we tapped (in case it's a copy)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    // ── Rollover check ───────────────────────────────────────
    
    func checkRollover() async {
        let td = DateUtils.today()
        let leftover = items.filter {
            $0.listDate < td && $0.status == .pending && $0.recurrence == .once
        }
        if !leftover.isEmpty {
            await MainActor.run {
                rolloverItems = leftover
                showRollover = true
            }
        }
    }

    func spawnRecurringItems() async {
        guard let userId else { return }
        let td = DateUtils.today()
        
        // Only true templates
        let templates = items.filter { $0.recurrence != .once && $0.templateId == nil }
        
        for template in templates {
            // Start from day after template's own date
            let startDate = DateUtils.adding(days: 1, to: template.listDate)
            let endDate60 = DateUtils.adding(days: 60, to: td)
            
            var datesToCheck: [String] = []
            var current = startDate
            while current <= endDate60 {
                datesToCheck.append(current)
                current = DateUtils.adding(days: 1, to: current)
            }
            
            var newItems: [TodoItem] = []
            
            for date in datesToCheck {
                if let endDate = template.recurrenceEndDate, date > endDate {
                    continue
                }
                
                let alreadyExists = items.contains {
                    $0.templateId == template.id && $0.listDate == date
                } || newItems.contains {
                    $0.templateId == template.id && $0.listDate == date
                }
                
                guard !alreadyExists else { continue }
                guard DateUtils.shouldSpawn(template, on: date) else { continue }
                
                let spawned = template.spawn(for: date)
                do {
                    let saved = try await service.insert(spawned)
                    newItems.append(saved)
                } catch {
                    self.error = error.localizedDescription
                }
            }
            
            if !newItems.isEmpty {
                await MainActor.run {
                    items.append(contentsOf: newItems)
                }
            }
        }
    }

    // ── Real-time ────────────────────────────────────────────

    private func subscribeRealtime(userId: UUID) {
        realtimeChannel = service.subscribeToChanges(
            userId: userId,
            onInsert: { [weak self] item in
                DispatchQueue.main.async {
                    guard let self, !self.items.contains(where: { $0.id == item.id }) else { return }
                    self.items.append(item)
                }
            },
            onUpdate: { [weak self] item in
                DispatchQueue.main.async { self?.apply(item) }
            },
            onDelete: { [weak self] id in
                DispatchQueue.main.async { self?.items.removeAll { $0.id == id } }
            }
        )
    }

    // ── Helpers ──────────────────────────────────────────────

    private func apply(_ item: TodoItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        }
    }
    
    func cleanup() {
        Task { await realtimeChannel?.unsubscribe() }
        items = []
        rolloverItems = []
        showRollover = false
        error = nil
        userId = nil
    }

    deinit {
        Task { await realtimeChannel?.unsubscribe() }
    }
}
