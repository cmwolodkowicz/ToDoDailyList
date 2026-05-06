import Foundation
import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Enums
// ─────────────────────────────────────────────────────────────

enum ItemStatus: String, Codable, CaseIterable {
    case pending   = "pending"
    case done      = "done"
    case obe       = "obe"      // Overtaken By Events — no longer needed
}

enum Recurrence: String, Codable, CaseIterable {
    case once      = "once"
    case daily     = "daily"
    case weekdays  = "weekdays"
    case weekends  = "weekends"
    case weekly    = "weekly"
    case biweekly  = "biweekly"
    case monthly   = "monthly"

    var displayName: String {
        switch self {
        case .once:     return "Just once"
        case .daily:    return "Every day"
        case .weekdays: return "Weekdays (Mon–Fri)"
        case .weekends: return "Weekends"
        case .weekly:   return "Every week"
        case .biweekly: return "Every 2 weeks"
        case .monthly:  return "Every month"
        }
    }
}

/// Minutes before deadline for a reminder. nil = no reminder.
enum ReminderOffset: Int, Codable, CaseIterable, Identifiable {
    case atTime      = 0
    case thirtyMin   = 30
    case oneHour     = 60
    case twoHours    = 120
    case threeHours  = 180
    case sixHours    = 360
    case twelveHours = 720
    case oneDay      = 1440
    case twoDays     = 2880
    case threeDays   = 4320
    case oneWeek     = 10080

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .atTime:      return "At time of deadline"
        case .thirtyMin:   return "30 minutes before"
        case .oneHour:     return "1 hour before"
        case .twoHours:    return "2 hours before"
        case .threeHours:  return "3 hours before"
        case .sixHours:    return "6 hours before"
        case .twelveHours: return "12 hours before"
        case .oneDay:      return "1 day before"
        case .twoDays:     return "2 days before"
        case .threeDays:   return "3 days before"
        case .oneWeek:     return "1 week before"
        }
    }
}

enum Priority: String, Codable, CaseIterable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var color: Color {
        switch self {
        case .low:    return .blue
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var icon: String {
        switch self {
        case .low:    return "arrow.down.circle.fill"
        case .medium: return "minus.circle.fill"
        case .high:   return "arrow.up.circle.fill"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - TodoItem
// ─────────────────────────────────────────────────────────────

struct TodoItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var userId: UUID
    var title: String
    var notes: String?

    /// The date this item appears on the list (YYYY-MM-DD)
    var listDate: String

    /// Optional hard deadline (YYYY-MM-DD HH:mm)
    var deadline: Date?

    /// Minutes before deadline to fire a reminder notification
    var reminderOffset: Int?

    var recurrence: Recurrence
    var status: ItemStatus
    var completedAt: Date?

    /// If this item was spawned by a recurring template, store the template's id
    var templateId: UUID?

    var createdAt: Date
    var updatedAt: Date
    
    var priority: Priority

    // ── CodingKeys to match Supabase snake_case columns ──────
    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case title
        case notes
        case listDate      = "list_date"
        case deadline
        case reminderOffset = "reminder_offset"
        case recurrence
        case status
        case completedAt   = "completed_at"
        case templateId    = "template_id"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
        case priority
    }

    // ── Convenience ──────────────────────────────────────────

    var isOverdue: Bool {
        guard let deadline, status == .pending else { return false }
        return deadline < Date()
    }

    var reminderOffsetEnum: ReminderOffset? {
        guard let v = reminderOffset else { return nil }
        return ReminderOffset(rawValue: v)
    }

    /// Returns the Date at which a reminder notification should fire
    var reminderFireDate: Date? {
        guard let deadline, let offset = reminderOffset else { return nil }
        return deadline.addingTimeInterval(TimeInterval(-offset * 60))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Factory
// ─────────────────────────────────────────────────────────────

extension TodoItem {
    static func create(
        userId: UUID,
        title: String,
        notes: String? = nil,
        listDate: String,
        deadline: Date? = nil,
        reminderOffset: Int? = nil,
        recurrence: Recurrence = .once,
        priority: Priority = .medium
    ) -> TodoItem {
        let now = Date()
        return TodoItem(
            id: UUID(),
            userId: userId,
            title: title,
            notes: notes,
            listDate: listDate,
            deadline: deadline,
            reminderOffset: reminderOffset,
            recurrence: recurrence,
            status: .pending,
            completedAt: nil,
            templateId: nil,
            createdAt: now,
            updatedAt: now,
            priority: priority
        )
    }

    /// Spawns a one-off copy of this recurring item for a given date
    func spawn(for date: String) -> TodoItem {
        var copy = self
        copy.id = UUID()
        copy.templateId = self.id
        copy.listDate = date
        copy.recurrence = .once
        copy.status = .pending
        copy.completedAt = nil
        copy.priority = self.priority
        copy.createdAt = Date()
        copy.updatedAt = Date()
        return copy
    }
}
