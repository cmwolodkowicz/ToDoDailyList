import SwiftUI

struct ItemFormView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    var editItem: TodoItem? = nil
    var defaultDate: String

    // ── Form state ───────────────────────────────────────────
    @State private var title = ""
    @State private var notes = ""
    @State private var listDate = DateUtils.today()
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var hasReminder = false
    @State private var reminderOffset: ReminderOffset = .oneDay
    @State private var recurrence: Recurrence = .once
    @State private var isSaving = false

    var isEditing: Bool { editItem != nil }
    var isValid:   Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // ── Task ─────────────────────────────────────
                Section("Task") {
                    TextField("What needs to be done?", text: $title, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .foregroundStyle(.secondary)
                }

                // ── Date ─────────────────────────────────────
                Section("Scheduling") {
                    DatePicker("List Date", selection: Binding(
                        get: { DateUtils.date(from: listDate) ?? Date() },
                        set: { listDate = DateUtils.string(from: $0) }
                    ), displayedComponents: .date)

                    Toggle("Has Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute])

                        Toggle("Set Reminder", isOn: $hasReminder)

                        if hasReminder {
                            Picker("Remind Me", selection: $reminderOffset) {
                                ForEach(ReminderOffset.allCases) { offset in
                                    Text(offset.displayName).tag(offset)
                                }
                            }
                        }
                    }
                }

                // ── Recurrence ───────────────────────────────
                Section("Frequency") {
                    Picker("Repeat", selection: $recurrence) {
                        ForEach(Recurrence.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                    .pickerStyle(.menu)

                    if recurrence != .once {
                        Label("A new item will be added to your list automatically", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { prefill() }
        }
    }

    // ── Prefill when editing ──────────────────────────────────

    private func prefill() {
        listDate = defaultDate

        guard let item = editItem else { return }
        title      = item.title
        notes      = item.notes ?? ""
        listDate   = item.listDate
        recurrence = item.recurrence

        if let d = item.deadline {
            hasDeadline = true
            deadline    = d
        }
        if let offset = item.reminderOffsetEnum {
            hasReminder    = true
            reminderOffset = offset
        }
    }

    // ── Save ─────────────────────────────────────────────────

    private func save() async {
        isSaving = true
        let finalDeadline       = hasDeadline ? deadline : nil
        let finalReminderOffset = (hasDeadline && hasReminder) ? reminderOffset.rawValue : nil

        if let existing = editItem {
            var updated = existing
            updated.title          = title.trimmingCharacters(in: .whitespaces)
            updated.notes          = notes.isEmpty ? nil : notes
            updated.listDate       = listDate
            updated.deadline       = finalDeadline
            updated.reminderOffset = finalReminderOffset
            updated.recurrence     = recurrence
            await todoVM.updateItem(updated)
        } else {
            await todoVM.addItem(
                title:          title.trimmingCharacters(in: .whitespaces),
                notes:          notes.isEmpty ? nil : notes,
                listDate:       listDate,
                deadline:       finalDeadline,
                reminderOffset: finalReminderOffset,
                recurrence:     recurrence
            )
        }
        isSaving = false
        dismiss()
    }
}
