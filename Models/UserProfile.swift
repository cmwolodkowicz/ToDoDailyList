import Foundation

struct UserProfile: Codable, Equatable {
    var id: UUID
    var email: String?
    var displayName: String?
    var dailyReminderEnabled: Bool
    var dailyReminderTime: String   // "HH:mm" e.g. "08:00"
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName           = "display_name"
        case dailyReminderEnabled  = "daily_reminder_enabled"
        case dailyReminderTime     = "daily_reminder_time"
        case createdAt             = "created_at"
    }

    static func defaultProfile(id: UUID, email: String?) -> UserProfile {
        UserProfile(
            id: id,
            email: email,
            displayName: nil,
            dailyReminderEnabled: true,
            dailyReminderTime: "08:00",
            createdAt: Date()
        )
    }
}
