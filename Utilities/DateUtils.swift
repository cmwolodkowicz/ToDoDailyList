import Foundation

enum DateUtils {
    static let listDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func today() -> String {
        listDateFormatter.string(from: Date())
    }

    static func yesterday() -> String {
        let d = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return listDateFormatter.string(from: d)
    }

    static func tomorrow() -> String {
        let d = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return listDateFormatter.string(from: d)
    }

    static func date(from string: String) -> Date? {
        listDateFormatter.date(from: string)
    }

    static func string(from date: Date) -> String {
        listDateFormatter.string(from: date)
    }

    static func displayString(for dateString: String) -> String {
        guard let d = date(from: dateString) else { return dateString }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: d)
    }

    /// Full formatted string for header — e.g. "Monday, April 14"
    static func headerString(for dateString: String) -> String {
        guard let d = date(from: dateString) else { return dateString }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: d)
    }

    /// Returns the weekday index (1 = Sunday, 7 = Saturday) for a list date string
    static func weekday(for dateString: String) -> Int? {
        guard let d = date(from: dateString) else { return nil }
        return Calendar.current.component(.weekday, from: d)
    }

    static func dayOfMonth(for dateString: String) -> Int? {
        guard let d = date(from: dateString) else { return nil }
        return Calendar.current.component(.day, from: d)
    }

    /// Advance a list date string by `n` days
    static func adding(days n: Int, to dateString: String) -> String {
        guard let d = date(from: dateString),
              let result = Calendar.current.date(byAdding: .day, value: n, to: d)
        else { return dateString }
        return string(from: result)
    }

    /// Number of full days between two list date strings (to - from)
    static func daysBetween(from: String, to: String) -> Int? {
        guard let d1 = date(from: from), let d2 = date(from: to) else { return nil }
        return Calendar.current.dateComponents([.day], from: d1, to: d2).day
    }

    /// Whether a recurring item should appear on a given date
    static func shouldSpawn(_ item: TodoItem, on targetDate: String) -> Bool {
        guard item.recurrence != .once else { return false }
        guard let targetWeekday = weekday(for: targetDate) else { return false }

        switch item.recurrence {
        case .once:
            return false
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(targetWeekday)
        case .weekends:
            return targetWeekday == 1 || targetWeekday == 7
        case .weekly:
            return weekday(for: item.listDate) == targetWeekday
        case .biweekly:
            guard let diff = daysBetween(from: item.listDate, to: targetDate) else { return false }
            return weekday(for: item.listDate) == targetWeekday && diff % 14 == 0
        case .monthly:
            return dayOfMonth(for: item.listDate) == dayOfMonth(for: targetDate)
        }
    }
}
