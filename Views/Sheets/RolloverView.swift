import SwiftUI

struct RolloverView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────
                VStack(spacing: 8) {
                    Text("🌅")
                        .font(.system(size: 52))
                    Text("Good morning!")
                        .font(.title2.weight(.bold))
                    Text("You have \(todoVM.rolloverItems.count) leftover item\(todoVM.rolloverItems.count == 1 ? "" : "s") from previous days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)
                .padding(.bottom, 20)

                Divider()

                // ── List ─────────────────────────────────────
                List {
                    ForEach(todoVM.rolloverItems) { item in
                        RolloverRow(item: item)
                            .environmentObject(todoVM)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Leftover Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        todoVM.showRollover = false
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct RolloverRow: View {
    @EnvironmentObject var todoVM: TodoViewModel
    let item: TodoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.body.weight(.medium))
            Text("From \(DateUtils.displayString(for: item.listDate))")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                RolloverButton(label: "✓  Done", color: .green) {
                    Task {
                        await todoVM.complete(item)
                        todoVM.rolloverItems.removeAll { $0.id == item.id }
                    }
                }
                RolloverButton(label: "→  Today", color: .orange) {
                    Task {
                        await todoVM.move(item, to: DateUtils.today())
                        todoVM.rolloverItems.removeAll { $0.id == item.id }
                    }
                }
                RolloverButton(label: "✕  OBE", color: .secondary) {
                    Task {
                        await todoVM.markOBE(item)
                        todoVM.rolloverItems.removeAll { $0.id == item.id }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

struct RolloverButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
