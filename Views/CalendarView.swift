//
//  CalendarView.swift
//  ToDoDailyList
//
//  Created by Chelsea Wolodkowicz on 5/12/26.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @Binding var selectedTab: Int
    @Binding var sharedDate: String
    @State private var selectedDate = DateUtils.today()
    @State private var displayedMonth = Date()
    @State private var editItem: TodoItem?
    @State private var showAddSheet = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthNavigator(displayedMonth: $displayedMonth)
                    .padding(.horizontal)
                    .padding(.top, 8)

                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 6)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
                        if let date {
                            DayCell(
                                dateString: date,
                                isSelected: date == sharedDate,
                                isToday: date == DateUtils.today(),
                                isPast: date < DateUtils.today(),
                                itemCount: todoVM.items(for: date).filter { $0.status == .pending }.count,
                                completedCount: todoVM.items(for: date).filter { $0.status == .done }.count,
                                items: todoVM.pending(for: date)
                            )
                            .onTapGesture {
                                sharedDate = date
                                selectedTab = 0
                            }
                        } else {
                            Color.clear
                                .frame(minHeight: 70)
                        }
                    }
                }
                .padding(.horizontal, 8)
                
                Spacer()
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // ── Helpers ───────────────────────────────────────────────

    private func daysInMonth() -> [String?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [String?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            var comps = components
            comps.day = day
            if let date = calendar.date(from: comps) {
                days.append(DateUtils.string(from: date))
            }
        }

        // Pad to complete last row
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}

// ── MonthNavigator ────────────────────────────────────────────

struct MonthNavigator: View {
    @Binding var displayedMonth: Date
    private let calendar = Calendar.current

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayedMonth)
    }

    var body: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(
                    byAdding: .month, value: -1, to: displayedMonth
                ) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color("Accent"))
            }

            Spacer()

            Text(monthLabel)
                .font(.title3.weight(.bold))

            Spacer()

            Button {
                displayedMonth = calendar.date(
                    byAdding: .month, value: 1, to: displayedMonth
                ) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color("Accent"))
            }
        }
        .padding(.vertical, 8)
    }
}

// ── DayCell ───────────────────────────────────────────────────

struct DayCell: View {
    let dateString: String
    let isSelected: Bool
    let isToday: Bool
    let isPast: Bool
    let itemCount: Int
    let completedCount: Int
    let items: [TodoItem]

    private var dayNumber: String {
        guard let date = DateUtils.date(from: dateString) else { return "" }
        return "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Day number circle
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color("Accent") : isToday ? Color("Accent").opacity(0.15) : Color.clear)
                        .frame(width: 28, height: 28)
                    Text(dayNumber)
                        .font(.system(size: 13, weight: isToday || isSelected ? .bold : .regular))
                        .foregroundStyle(
                            isSelected ? .white :
                            isToday ? Color("Accent") :
                            isPast ? .secondary : .primary
                        )
                }
                Spacer()
            }

            // Item previews
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items.prefix(3)) { item in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(priorityColor(item.priority))
                                .frame(width: 5, height: 5)
                            Text(item.title)
                                .font(.system(size: 8))
                                .foregroundStyle(.primary.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    if items.count > 3 {
                        Text("+\(items.count - 3) more")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color("Accent").opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color("Accent").opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .blue
        }
    }
}
