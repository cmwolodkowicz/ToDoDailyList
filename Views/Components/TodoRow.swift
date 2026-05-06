import SwiftUI

struct TodoRow: View {
    @EnvironmentObject var todoVM: TodoViewModel
    let item: TodoItem

    @State private var showMoveSheet = false
    @State private var showDeleteConfirm = false

    var isDone: Bool { item.status == .done }
    var isOBE:  Bool { item.status == .obe }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // ── Checkbox / status icon ───────────────────────
            Button {
                if isDone || isOBE {
                    Task { await todoVM.revertToPending(item) }
                } else {
                    Task { await todoVM.complete(item) }
                }
            } label: {
                statusIcon
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // ── Content ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .strikethrough(isDone || isOBE)
                    .foregroundStyle(isDone || isOBE ? .tertiary : .primary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Meta tags
                VStack(alignment: .leading, spacing: 4) {
                    // Priority always shows
                    
                    if let deadline = item.deadline {
                        MetaTag(
                            icon: "flag.fill",
                            text: shortDate(deadline),
                            color: item.isOverdue ? .red : .orange
                        )
                    }
                    if item.reminderOffset != nil {
                        MetaTag(icon: "bell.fill", text: "Reminder set", color: .indigo)
                    }
                    if item.recurrence != .once {
                        MetaTag(icon: "repeat", text: item.recurrence.displayName, color: .teal)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isDone && !isOBE {
                Button(role: .destructive) {
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        await todoVM.delete(item)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    showMoveSheet = true
                } label: {
                    Label("Move", systemImage: "arrow.right.circle")
                }
                .tint(.orange)

                Button {
                    Task { await todoVM.markOBE(item) }
                } label: {
                    Label("OBE", systemImage: "xmark.circle")
                }
                .tint(.gray)
            }

            if isDone || isOBE {
                Button {
                    Task { await todoVM.revertToPending(item) }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.left")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isDone && !isOBE {
                Button {
                    Task { await todoVM.complete(item) }
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
        .confirmationDialog("Delete this item?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await todoVM.delete(item) }
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveDateSheet(item: item)
                .environmentObject(todoVM)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        } else if isOBE {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(item.isOverdue ? .red : Color("Accent"))
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400) != 0 ? .short : .none
        return f.string(from: date)
    }
}

// ── MetaTag ───────────────────────────────────────────────────

struct MetaTag: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
