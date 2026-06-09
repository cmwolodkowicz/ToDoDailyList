import SwiftUI

struct TodoRow: View {
    @EnvironmentObject var todoVM: TodoViewModel
    let item: TodoItem

    @State private var showMoveSheet = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteOptions = false
    @State private var showEditOptions = false
    @State private var editThisItem: TodoItem? = nil
    @State private var editingItem = false

    var isDone: Bool { item.status == .done && item.movedToDate == nil }
    var isMoved: Bool { item.status == .done && item.movedToDate != nil }
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
                    .strikethrough(isDone || isOBE || isMoved)
                    .foregroundStyle(isDone || isOBE || isMoved ? .tertiary : .primary)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                // Moved note
                if let movedTo = item.movedToDate {
                    Label("Moved to \(DateUtils.displayString(for: movedTo))", systemImage: "arrow.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }

                // Meta tags
                VStack(alignment: .leading, spacing: 4) {
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
                    if item.recurrence != .once || item.templateId != nil {
                        MetaTag(icon: "repeat", text: "Recurring", color: .teal)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isDone && !isOBE {
                if item.recurrence != .once || item.templateId != nil {
                    // Recurring — show options dialog, no destructive role
                    Button {
                        showDeleteOptions = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                } else {
                    // Non-recurring — delete directly
                    Button(role: .destructive) {
                        Task { await todoVM.delete(item) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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
        .confirmationDialog("Delete Item", isPresented: $showDeleteOptions, titleVisibility: .visible) {
            Button("Delete This Occurrence Only", role: .destructive) {
                Task { await todoVM.delete(item) }
            }
            Button("Delete Entire Series", role: .destructive) {
                Task { await todoVM.deleteSeries(item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is a recurring item. Do you want to delete just this occurrence or the entire series?")
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveDateSheet(item: item)
                .environmentObject(todoVM)
        }
        .confirmationDialog("Edit Recurring Item", isPresented: $showEditOptions, titleVisibility: .visible) {
            Button("Edit This Occurrence Only") {
                editThisItem = item
            }
            Button("Edit Entire Series") {
                // Pass the template to edit
                if let templateId = item.templateId,
                   let template = todoVM.items.first(where: { $0.id == templateId }) {
                    editThisItem = template
                } else {
                    editThisItem = item
                }
                editingItem = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to edit just this occurrence or the entire series?")
        }
        .sheet(item: $editThisItem) { itemToEdit in
            ItemFormView(
                editItem: itemToEdit,
                defaultDate: itemToEdit.listDate,
                editEntireSeries: editingItem
            )
            .environmentObject(todoVM)
            .onDisappear { editingItem = false }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        } else if isMoved {
            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
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
