import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @State private var selectedDate: String?

    var body: some View {
        NavigationStack {
            Group {
                if todoVM.allListDates.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Your past lists will appear here.")
                    )
                } else {
                    List(todoVM.allListDates, id: \.self) { date in
                        NavigationLink(destination: HistoryDetailView(date: date)) {
                            HistoryRow(date: date, items: todoVM.items(for: date))
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }
}

struct HistoryRow: View {
    let date: String
    let items: [TodoItem]

    private var doneCount:    Int { items.filter { $0.status == .done }.count }
    private var pendingCount: Int { items.filter { $0.status == .pending }.count }
    private var obeCount:     Int { items.filter { $0.status == .obe }.count }
    private var total:        Int { items.count }
    private var progress:     Double { total > 0 ? Double(doneCount) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(DateUtils.displayString(for: date))
                    .font(.headline)
                Spacer()
                Text("\(doneCount)/\(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(progress == 1 ? .green : .orange)
                .scaleEffect(x: 1, y: 1.5)

            HStack(spacing: 10) {
                if doneCount > 0    { miniChip("\(doneCount) done",    .green) }
                if pendingCount > 0 { miniChip("\(pendingCount) left", .orange) }
                if obeCount > 0     { miniChip("\(obeCount) OBE",      .secondary) }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func miniChip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    let date: String

    var items: [TodoItem]   { todoVM.items(for: date) }
    var pending: [TodoItem] { items.filter { $0.status == .pending } }
    var done: [TodoItem]    { items.filter { $0.status == .done } }
    var obe: [TodoItem]     { items.filter { $0.status == .obe } }

    var body: some View {
        List {
            if !pending.isEmpty {
                Section("Pending") {
                    ForEach(pending) { item in
                        TodoRow(item: item).environmentObject(todoVM)
                    }
                }
            }
            if !done.isEmpty {
                Section("Completed") {
                    ForEach(done) { item in
                        TodoRow(item: item).environmentObject(todoVM)
                    }
                }
            }
            if !obe.isEmpty {
                Section("No Longer Needed") {
                    ForEach(obe) { item in
                        TodoRow(item: item).environmentObject(todoVM)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(DateUtils.headerString(for: date))
        .navigationBarTitleDisplayMode(.inline)
    }
}
