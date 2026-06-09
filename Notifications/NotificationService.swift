import Foundation
import Combine
import UserNotifications

final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    // ── Authorization ────────────────────────────────────────

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // ── Daily reminder ───────────────────────────────────────

    func scheduleDailyReminder(time: String = "08:00") {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }

        var comps = DateComponents()
        comps.hour = parts[0]
        comps.minute = parts[1]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "DailyList 📋"
        content.body  = "Good morning! Ready to plan your day?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // ── Item reminders ───────────────────────────────────────

    func scheduleReminder(for item: TodoItem) {
        // Use deadline-based reminder if available, otherwise use direct reminder date
        let fireDate = item.reminderFireDate ?? item.reminderDate
        guard let fireDate, fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body  = reminderBody(for: item)
        content.sound = .default
        content.userInfo = ["itemId": item.id.uuidString]

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: notifId(for: item.id),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelReminder(for itemId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [notifId(for: itemId)])
    }

    // ── Foreground presentation ──────────────────────────────

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // ── Helpers ──────────────────────────────────────────────

    private func notifId(for itemId: UUID) -> String {
        "item-\(itemId.uuidString)"
    }

    private func reminderBody(for item: TodoItem) -> String {
        if let deadline = item.deadline {
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            return "Due \(fmt.string(from: deadline))"
        }
        return "Reminder for your DailyList item"
    }
}
