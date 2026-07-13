import Foundation
import Combine
import Supabase
import SwiftUI

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
        print("DEBUG: Bootstrap started")
        self.userId = userId
        await fetchAll(userId: userId)
        print("DEBUG: fetchAll complete, items count: \(items.count)")
        
        // Only spawn if we haven't done so today
        let lastSpawnKey = "lastSpawnDate_\(userId.uuidString)"
        let lastSpawn = UserDefaults.standard.string(forKey: lastSpawnKey)
        let td = DateUtils.today()
        
        if lastSpawn != td {
            print("DEBUG: Running spawn")
            await spawnRecurringItems()
            UserDefaults.standard.set(td, forKey: lastSpawnKey)
            print("DEBUG: Spawn complete")
        } else {
            print("DEBUG: Skipping spawn, already ran today")
        }
        
        await checkRollover()
        print("DEBUG: checkRollover complete, showRollover: \(showRollover), rolloverItems: \(rolloverItems.count)")
        subscribeRealtime(userId: userId)
        notifs.scheduleDailyReminder()
        print("DEBUG: Bootstrap complete")
    }

    // ── Fetch ────────────────────────────────────────────────

    func fetchAll(userId: UUID) async {
        isLoading = true
        do {
            let start = DateUtils.adding(days: -30, to: DateUtils.today())
            let end = DateUtils.adding(days: 180, to: DateUtils.today())
            var fetched = try await service.fetch(userId: userId, from: start, to: end)
            
            // Always fetch recurring templates regardless of their list_date
            let templates = try await service.fetchTemplates(userId: userId)
            
            // Merge templates in, avoiding duplicates
            for template in templates {
                if !fetched.contains(where: { $0.id == template.id }) {
                    fetched.append(template)
                }
            }
            
            items = fetched
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
        reminderDate: Date? = nil,
        recurrence: Recurrence,
        priority: Priority = .medium,
        recurrenceEndDate: String? = nil
    ) async {
        guard let userId else { return }
        
        // Calculate next order index for this date/priority group
        let existingItems = items.filter {
            $0.listDate == listDate &&
            $0.priority == priority &&
            $0.status == .pending
        }
        let nextIndex = (existingItems.map { $0.orderIndex }.max() ?? -1) + 1
        
        var item = TodoItem.create(
            userId: userId,
            title: title,
            notes: notes,
            listDate: listDate,
            deadline: deadline,
            reminderOffset: reminderOffset,
            recurrence: recurrence,
            priority: priority,
            orderIndex: nextIndex
        )
        item.recurrenceEndDate = recurrenceEndDate
        item.reminderDate = reminderDate
        do {
            let saved = try await service.insert(item)
            await MainActor.run {
                items.append(saved)
            }
            notifs.scheduleReminder(for: saved)
            
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
    
    func updateSeries(_ item: TodoItem) async {
        let templateId = item.templateId ?? item.id
        
        // Get the fields we want to propagate to all occurrences
        do {
            // Update the template itself
            if let templateIndex = items.firstIndex(where: { $0.id == templateId }) {
                var template = items[templateIndex]
                template.title = item.title
                template.notes = item.notes
                template.priority = item.priority
                template.deadline = item.deadline
                template.reminderOffset = item.reminderOffset
                template.recurrenceEndDate = item.recurrenceEndDate
                template.updatedAt = Date()
                let savedTemplate = try await service.update(template)
                await MainActor.run { items[templateIndex] = savedTemplate }
            }
            
            // Update all spawned copies
            let copies = items.filter { $0.templateId == templateId }
            for copy in copies {
                var updated = copy
                updated.title = item.title
                updated.notes = item.notes
                updated.priority = item.priority
                updated.deadline = item.deadline
                updated.reminderOffset = item.reminderOffset
                updated.recurrenceEndDate = item.recurrenceEndDate
                updated.updatedAt = Date()
                let saved = try await service.update(updated)
                await MainActor.run {
                    if let i = self.items.firstIndex(where: { $0.id == copy.id }) {
                        self.items[i] = saved
                    }
                }
                notifs.cancelReminder(for: copy.id)
                notifs.scheduleReminder(for: saved)
            }
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
    
//    func checkRollover() async {
//        let td = DateUtils.today()
//        let leftover = items.filter {
//            $0.listDate < td &&
//            $0.status == .pending &&
//            $0.recurrence == .once &&
//            $0.templateId == nil  // exclude spawned recurring copies
//        }
//        if !leftover.isEmpty {
//            await MainActor.run {
//                rolloverItems = leftover
//                showRollover = true
//            }
//        }
//    }
    func checkRollover() async {
        let td = DateUtils.today()
        let leftover = items.filter {
            $0.listDate < td &&
            $0.status == .pending &&
            $0.recurrence == .once &&
            $0.templateId == nil
        }
        print("DEBUG: Rollover leftover count: \(leftover.count)")
        print("DEBUG: Leftover titles: \(leftover.map { $0.title })")
        
        // Temporarily force show even if empty to test the sheet
        await MainActor.run {
            rolloverItems = leftover
            showRollover = true
            print("DEBUG: showRollover set to \(showRollover)")
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
            let endDate360 = DateUtils.adding(days: 360, to: td)
            
            var datesToCheck: [String] = []
            var current = startDate
            while current <= endDate360 {
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
                    // Silently ignore unique constraint violations (duplicate spawns)
                    // Any other error should still be reported
                    let errorString = error.localizedDescription
                    if !errorString.contains("duplicate") && !errorString.contains("unique") {
                        self.error = errorString
                    }
                }
            }
            
            if !newItems.isEmpty {
                await MainActor.run {
                    items.append(contentsOf: newItems)
                }
            }
            
        }
    }
    
    func reorder(items sectionItems: [TodoItem], from source: IndexSet, to destination: Int) async {
        // Build the new order
        var reordered = sectionItems
        reordered.move(fromOffsets: source, toOffset: destination)
        
        // Assign new order indices
        var updates: [(id: UUID, orderIndex: Int)] = []
        for (index, item) in reordered.enumerated() {
            updates.append((id: item.id, orderIndex: index))
            
            // Update local array immediately
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                items[i].orderIndex = index
            }
        }
        
        // Persist to database
        do {
            try await service.updateOrderIndices(updates)
            
            // If any item is recurring, sync order to all occurrences
            for item in reordered {
                let templateId = item.templateId ?? (item.recurrence != .once ? item.id : nil)
                if let templateId {
                    let newIndex = updates.first { $0.id == item.id }?.orderIndex ?? 0
                    try await service.updateOrderIndicesForSeries(
                        templateId: templateId,
                        orderIndex: newIndex
                    )
                    // Update all local copies too
                    await MainActor.run {
                        for i in self.items.indices {
                            if self.items[i].templateId == templateId || self.items[i].id == templateId {
                                self.items[i].orderIndex = newIndex
                            }
                        }
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
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
