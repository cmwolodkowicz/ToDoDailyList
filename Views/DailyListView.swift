import SwiftUI

struct DailyListView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @Binding var sharedDate: String
    @State private var showAddSheet = false
    @State private var editItem: TodoItem?
    @State private var pendingEditItem: TodoItem? = nil
    @State private var showEditOptions = false
    @State private var editEntireSeries = false

    var pending: [TodoItem] {
        todoVM.pending(for: sharedDate)
            .filter { !isDailySpawn($0) }
            .sorted {
                let order: [Priority] = [.high, .medium, .low]
                let i0 = order.firstIndex(of: $0.priority) ?? 1
                let i1 = order.firstIndex(of: $1.priority) ?? 1
                if i0 != i1 { return i0 < i1 }
                return $0.orderIndex < $1.orderIndex
            }
    }

    var dailyItems: [TodoItem] {
        todoVM.pending(for: sharedDate)
            .filter { isDailySpawn($0) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private func isDailySpawn(_ item: TodoItem) -> Bool {
        if item.recurrence == .daily { return true }
        if let templateId = item.templateId,
           let template = todoVM.items.first(where: { $0.id == templateId }) {
            return template.recurrence == .daily
        }
        return false
    }

    var completed: [TodoItem] { todoVM.completed(for: sharedDate).filter { $0.movedToDate == nil } }
    var moved: [TodoItem]     { todoVM.completed(for: sharedDate).filter { $0.movedToDate != nil } }
    var obeItems: [TodoItem]  { todoVM.obe(for: sharedDate) }
    var allItems: [TodoItem]  { todoVM.items(for: sharedDate) }

    var isToday: Bool { sharedDate == DateUtils.today() }
    var isPast:  Bool { sharedDate < DateUtils.today() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Date navigator ───────────────────────────
                DateNavigator(sharedDate: $sharedDate)
                    .padding(.horizontal)
                    .padding(.top, 4)

                // ── Stats bar ────────────────────────────────
                StatsBar(
                    pending: pending.count + dailyItems.count,
                    done: completed.count,
                    moved: moved.count,
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
                        let highItems   = pending.filter { $0.priority == .high }
                        let mediumItems = pending.filter { $0.priority == .medium }
                        let lowItems    = pending.filter { $0.priority == .low }

                        // ── High Priority ────────────────────
                        if !highItems.isEmpty {
                            Section {
                                ForEach(highItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { handleTap(item) }
                                }
                                .onMove { source, destination in
                                    Task { await todoVM.reorder(items: highItems, from: source, to: destination) }
                                }
                            } header: {
                                Label("High Priority", systemImage: "arrow.up.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        // ── Medium Priority ──────────────────
                        if !mediumItems.isEmpty {
                            Section {
                                ForEach(mediumItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { handleTap(item) }
                                }
                                .onMove { source, destination in
                                    Task { await todoVM.reorder(items: mediumItems, from: source, to: destination) }
                                }
                            } header: {
                                Label("Medium Priority", systemImage: "minus.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        // ── Low Priority ─────────────────────
                        if !lowItems.isEmpty {
                            Section {
                                ForEach(lowItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { handleTap(item) }
                                }
                                .onMove { source, destination in
                                    Task { await todoVM.reorder(items: lowItems, from: source, to: destination) }
                                }
                            } header: {
                                Label("Low Priority", systemImage: "arrow.down.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        // ── Daily To Do's ────────────────────
                        if !dailyItems.isEmpty {
                            Section {
                                ForEach(dailyItems) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                        .onTapGesture { handleTap(item) }
                                }
                                .onMove { source, destination in
                                    Task { await todoVM.reorder(items: dailyItems, from: source, to: destination) }
                                }
                            } header: {
                                Label("Daily To Do's", systemImage: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(.purple)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        // ── Completed ────────────────────────
                        if !completed.isEmpty {
                            Section("Completed") {
                                ForEach(completed) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                }
                            }
                        }

                        // ── Moved ────────────────────────────
                        if !moved.isEmpty {
                            Section("Moved") {
                                ForEach(moved) { item in
                                    TodoRow(item: item)
                                        .environmentObject(todoVM)
                                }
                            }
                        }

                        // ── No Longer Needed ─────────────────
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
            .navigationTitle(sharedDate == DateUtils.today() ? "Today" : DateUtils.headerString(for: sharedDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .foregroundStyle(Color("Accent"))
                }
                if sharedDate != DateUtils.today() {
                    ToolbarItem(placement: .principal) {
                        Button {
                            sharedDate = DateUtils.today()
                        } label: {
                            Text("Go to Today")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("Accent"))
                        }
                    }
                }
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
            .confirmationDialog("Edit Recurring Item", isPresented: $showEditOptions, titleVisibility: .visible) {
                Button("Edit This Occurrence Only") {
                    editEntireSeries = false
                    editItem = pendingEditItem
                }
                Button("Edit Entire Series") {
                    editEntireSeries = true
                    if let templateId = pendingEditItem?.templateId,
                       let template = todoVM.items.first(where: { $0.id == templateId }) {
                        print("DEBUG: Found template - title: \(template.title), recurrence: \(template.recurrence), templateId: \(String(describing: template.templateId))")
                        editItem = template
                    } else {
                        print("DEBUG: No template found, using pendingEditItem - title: \(String(describing: pendingEditItem?.title)), recurrence: \(String(describing: pendingEditItem?.recurrence))")
                        editItem = pendingEditItem
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingEditItem = nil
                }
            } message: {
                Text("Do you want to edit just this occurrence or the entire series?")
            }
            .sheet(isPresented: $showAddSheet) {
                ItemFormView(defaultDate: sharedDate)
                    .environmentObject(todoVM)
            }
            .sheet(item: $editItem) { item in
                ItemFormView(
                    editItem: item,
                    defaultDate: sharedDate,
                    editEntireSeries: editEntireSeries
                )
                .environmentObject(todoVM)
                .onDisappear { editEntireSeries = false }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────

    private func handleTap(_ item: TodoItem) {
        if item.recurrence != .once || item.templateId != nil {
            pendingEditItem = item
            showEditOptions = true
        } else {
            editItem = item
        }
    }
}

// ── DateNavigator ─────────────────────────────────────────────

struct DateNavigator: View {
    @Binding var sharedDate: String

    private var label: String {
        if sharedDate == DateUtils.today()     { return "Today" }
        if sharedDate == DateUtils.yesterday() { return "Yesterday" }
        if sharedDate == DateUtils.tomorrow()  { return "Tomorrow" }
        return sharedDate < DateUtils.today() ? "Past" : "Upcoming"
    }

    var body: some View {
        HStack {
            Button {
                sharedDate = DateUtils.adding(days: -1, to: sharedDate)
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
                Text(DateUtils.headerString(for: sharedDate))
                    .font(.title3.weight(.bold))
            }

            Spacer()

            Button {
                sharedDate = DateUtils.adding(days: 1, to: sharedDate)
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
    let moved: Int
    let obe: Int

    var body: some View {
        HStack(spacing: 10) {
            StatChip(label: "To Do",  count: pending, color: .orange)
            StatChip(label: "Done",   count: done,    color: .green)
            StatChip(label: "Moved",  count: moved,   color: .orange)
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
