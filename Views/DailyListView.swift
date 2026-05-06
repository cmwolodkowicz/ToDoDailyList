import SwiftUI

struct DailyListView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @State private var viewDate = DateUtils.today()
    @State private var showAddSheet = false
    @State private var editItem: TodoItem?

    var pending: [TodoItem] {
        todoVM.pending(for: viewDate).sorted {
            let order: [Priority] = [.high, .medium, .low]
            let i0 = order.firstIndex(of: $0.priority) ?? 1
            let i1 = order.firstIndex(of: $1.priority) ?? 1
            return i0 < i1
        }
    }
    var completed: [TodoItem] { todoVM.completed(for: viewDate) }
    var obeItems:  [TodoItem] { todoVM.obe(for: viewDate) }
    var allItems:  [TodoItem] { todoVM.items(for: viewDate) }

    var isToday:  Bool { viewDate == DateUtils.today() }
    var isPast:   Bool { viewDate < DateUtils.today() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Date navigator ───────────────────────────
                DateNavigator(viewDate: $viewDate)
                    .padding(.horizontal)
                    .padding(.top, 4)

                // ── Stats bar ────────────────────────────────
                StatsBar(
                    pending: pending.count,
                    done: completed.count,
                    obe: obeItems.count
                )
                .padding(.horizontal)
                .padding(.top, 10)

                // ── List ─────────────────────────────────────
                if todoVM.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if allItems.isEmpty {
                    EmptyListView(isToday: isToday)
                } else {
                    List {
                        // Pending
                        // High priority
                        let highItems = pending.filter { $0.priority == .high }
                        let mediumItems = pending.filter { $0.priority == .medium }
                        let lowItems = pending.filter { $0.priority == .low }

                        if !highItems.isEmpty {
                            Section {
                                ForEach(highItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { editItem = item }
                                }
                            } header: {
                                Label("High Priority", systemImage: "arrow.up.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        if !mediumItems.isEmpty {
                            Section {
                                ForEach(mediumItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { editItem = item }
                                }
                            } header: {
                                Label("Medium Priority", systemImage: "minus.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        if !lowItems.isEmpty {
                            Section {
                                ForEach(lowItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { editItem = item }
                                }
                            } header: {
                                Label("Low Priority", systemImage: "arrow.down.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        // Completed
                        if !completed.isEmpty {
                            Section("Completed") {
                                ForEach(completed) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                }
                            }
                        }

                        // OBE
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
            .navigationTitle("DailyList")
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
                ItemFormView(defaultDate: viewDate)
                    .environmentObject(todoVM)
            }
            .sheet(item: $editItem) { item in
                ItemFormView(editItem: item, defaultDate: viewDate)
                    .environmentObject(todoVM)
            }
        }
    }
}

// ── DateNavigator ─────────────────────────────────────────────

struct DateNavigator: View {
    @Binding var viewDate: String

    private var label: String {
        if viewDate == DateUtils.today()     { return "Today" }
        if viewDate == DateUtils.yesterday() { return "Yesterday" }
        if viewDate == DateUtils.tomorrow()  { return "Tomorrow" }
        return viewDate < DateUtils.today() ? "Past" : "Upcoming"
    }

    var body: some View {
        HStack {
            Button {
                viewDate = DateUtils.adding(days: -1, to: viewDate)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color("Accent"))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Accent"))
                    .textCase(.uppercase)
                    .kerning(1.2)
                Text(DateUtils.headerString(for: viewDate))
                    .font(.title3.weight(.bold))
            }

            Spacer()

            Button {
                viewDate = DateUtils.adding(days: 1, to: viewDate)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color("Accent"))
            }
        }
        .padding(.vertical, 8)
    }
}

// ── StatsBar ──────────────────────────────────────────────────

struct StatsBar: View {
    let pending: Int
    let done: Int
    let obe: Int

    var body: some View {
        HStack(spacing: 10) {
            StatChip(label: "To Do",  count: pending, color: .orange)
            StatChip(label: "Done",   count: done,    color: .green)
            StatChip(label: "OBE",    count: obe,     color: .secondary)
        }
    }
}

struct StatChip: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.25), lineWidth: 1))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }
}

// ── EmptyListView ─────────────────────────────────────────────

struct EmptyListView: View {
    let isToday: Bool

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text(isToday ? "Nothing on today's list" : "No items for this day")
                .font(.headline)
                .foregroundStyle(.secondary)
            if isToday {
                Text("Tap + to add something")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}
