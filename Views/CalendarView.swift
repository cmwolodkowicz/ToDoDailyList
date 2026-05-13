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
                // ── Month navigator ──────────────────────────
                MonthNavigator(displayedMonth: $displayedMonth)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // ── Weekday headers ──────────────────────────
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
                .padding(.bottom, 4)

                // ── Calendar grid ────────────────────────────
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
                        if let date {
                            DayCell(
                                dateString: date,
                                isSelected: date == sharedDate,
                                isToday: date == DateUtils.today(),
                                isPast: date < DateUtils.today(),
                                itemCount: todoVM.items(for: date).filter { $0.status == .pending }.count,
                                completedCount: todoVM.items(for: date).filter { $0.status == .done }.count
                            )
                            .onTapGesture {
                                sharedDate = date
                                selectedTab = 0
                            }
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 8)

                Divider()
                    .padding(.top, 12)

                // ── Selected day list ────────────────────────
                SelectedDayView(
                    date: selectedDate,
                    editItem: $editItem,
                    showAddSheet: $showAddSheet
                )
                .environmentObject(todoVM)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("Accent"))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ItemFormView(defaultDate: sharedDate)
                    .environmentObject(todoVM)
            }
            .sheet(item: $editItem) { item in
                ItemFormView(editItem: item, defaultDate: sharedDate)
                    .environmentObject(todoVM)
            }
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

    private var dayNumber: String {
        guard let date = DateUtils.date(from: dateString) else { return "" }
        return "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Background
                Circle()
                    .fill(isSelected ? Color("Accent") : isToday ? Color("Accent").opacity(0.15) : Color.clear)
                    .frame(width: 36, height: 36)

                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? Color("Accent") :
                        isPast ? .secondary : .primary
                    )
            }

            // Dot indicators
            HStack(spacing: 3) {
                if itemCount > 0 {
                    Circle()
                        .fill(Color("Accent"))
                        .frame(width: 5, height: 5)
                }
                if completedCount > 0 {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 52)
    }
}

// ── SelectedDayView ───────────────────────────────────────────

struct SelectedDayView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    let date: String
    @Binding var editItem: TodoItem?
    @Binding var showAddSheet: Bool

    var allItems: [TodoItem] { todoVM.items(for: date) }
    var pending: [TodoItem] {
        todoVM.pending(for: date).sorted {
            let order: [Priority] = [.high, .medium, .low]
            let i0 = order.firstIndex(of: $0.priority) ?? 1
            let i1 = order.firstIndex(of: $1.priority) ?? 1
            if i0 != i1 { return i0 < i1 }
            return $0.orderIndex < $1.orderIndex
        }
    }
    var completed: [TodoItem] { todoVM.completed(for: date).filter { $0.movedToDate == nil } }
    var moved: [TodoItem] { todoVM.completed(for: date).filter { $0.movedToDate != nil } }
    var obeItems: [TodoItem] { todoVM.obe(for: date) }

    var body: some View {
        VStack(spacing: 0) {
            // Day header
            HStack {
                Text(DateUtils.headerString(for: date))
                    .font(.headline)
                Spacer()
                Text("\(pending.count) pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            if allItems.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No items for this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("Accent"))
                    }
                    Spacer()
                }
            } else {
                List {
                    if !pending.isEmpty {
                        Section("Pending") {
                            ForEach(pending) { item in
                                TodoRow(item: item)
                                    .environmentObject(todoVM)
                                    .onTapGesture { editItem = item }
                            }
                        }
                    }
                    if !completed.isEmpty {
                        Section("Completed") {
                            ForEach(completed) { item in
                                TodoRow(item: item)
                                    .environmentObject(todoVM)
                            }
                        }
                    }
                    if !moved.isEmpty {
                        Section("Moved") {
                            ForEach(moved) { item in
                                TodoRow(item: item)
                                    .environmentObject(todoVM)
                            }
                        }
                    }
                    if !obeItems.isEmpty {
                        Section("No Longer Needed") {
                            ForEach(obeItems) { item in
                                TodoRow(item: item)
                                    .environmentObject(todoVM)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
