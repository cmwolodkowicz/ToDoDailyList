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
            items = try await service.fetchAll(userId: userId)
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
        recurrence: Recurrence
    ) async {
        guard let userId else { return }
        let item = TodoItem.create(
            userId: userId,
            title: title,
            notes: notes,
            listDate: listDate,
            deadline: deadline,
            reminderOffset: reminderOffset,
            recurrence: recurrence
        )
        do {
            let saved = try await service.insert(item)
            items.append(saved)
            notifs.scheduleReminder(for: saved)
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
        var updated = item
        updated.listDate = date
        updated.status = .pending
        await updateItem(updated)
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
        do {
            try await service.delete(id: item.id)
            items.removeAll { $0.id == item.id }
            notifs.cancelReminder(for: item.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // ── Rollover check ───────────────────────────────────────

    func checkRollover() async {
        let td = DateUtils.today()
        let leftover = items.filter {
            $0.listDate < td && $0.status == .pending && $0.recurrence == .once
        }
        if !leftover.isEmpty {
            rolloverItems = leftover
            showRollover = true
        }
    }

    // ── Recurring item spawning ──────────────────────────────

    func spawnRecurringItems() async {
        guard let userId else { return }
        let td = DateUtils.today()
        let templates = items.filter { $0.recurrence != .once }

        for template in templates {
            let alreadyExists = items.contains {
                $0.templateId == template.id && $0.listDate == td
            }
            guard !alreadyExists, DateUtils.shouldSpawn(template, on: td) else { continue }

            let spawned = template.spawn(for: td)
            do {
                let saved = try await service.insert(spawned)
                items.append(saved)
            } catch {
                self.error = error.localizedDescription
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

    deinit {
        Task { await realtimeChannel?.unsubscribe() }
    }
}
