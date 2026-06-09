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
    @State private var priority: Priority = .medium
    @State private var hasEndDate = false
    @State private var recurrenceEndDate = Date()
    @State private var reminderDateTime = Date()

    var isEditing: Bool { editItem != nil }
    var isValid:   Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    var editEntireSeries: Bool = false

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
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.icon)
                                .foregroundStyle(p.color)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
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
                    }
                }

                Section("Reminder") {
                    Toggle("Set Reminder", isOn: $hasReminder)

                    if hasReminder {
                        if hasDeadline {
                            Picker("Remind Me", selection: $reminderOffset) {
                                ForEach(ReminderOffset.allCases) { offset in
                                    Text(offset.displayName).tag(offset)
                                }
                            }
                        } else {
                            DatePicker("Reminder Time", selection: $reminderDateTime, displayedComponents: [.date, .hourAndMinute])
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
                        Toggle("Set End Date", isOn: $hasEndDate)
                        
                        if hasEndDate {
                            DatePicker(
                                "End Date",
                                selection: $recurrenceEndDate,
                                in: (DateUtils.date(from: listDate) ?? Date())...,
                                displayedComponents: .date
                            )
                        } else {
                            Label("Repeats indefinitely", systemImage: "infinity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
            .onAppear {
                if let item = editItem {
                    title      = item.title
                    notes      = item.notes ?? ""
                    listDate   = item.listDate
                    recurrence = item.recurrence
                    priority   = item.priority
                    
                    if let d = item.deadline {
                        hasDeadline = true
                        deadline    = d
                    }
                    if let offset = item.reminderOffsetEnum {
                        hasReminder    = true
                        reminderOffset = offset
                    }
                    if let rd = item.reminderDate {
                        hasReminder      = true
                        reminderDateTime = rd
                    }
                    if let endDate = item.recurrenceEndDate {
                        hasEndDate        = true
                        recurrenceEndDate = DateUtils.date(from: endDate) ?? Date()
                    }
                } else {
                    listDate = defaultDate
                }
            }
        }
    }

    // ── Prefill when editing ──────────────────────────────────

    private func prefill() {
        guard let item = editItem else { return }
        title      = item.title
        notes      = item.notes ?? ""
        listDate   = item.listDate
        recurrence = item.recurrence
        priority   = item.priority

        if let d = item.deadline {
            hasDeadline = true
            deadline    = d
        }
        if let offset = item.reminderOffsetEnum {
            hasReminder    = true
            reminderOffset = offset
        }
        if let endDate = item.recurrenceEndDate {
            hasEndDate = true
            recurrenceEndDate = DateUtils.date(from: endDate) ?? Date()
        }
        if let rd = item.reminderDate {
            hasReminder = true
            reminderDateTime = rd
        }
    }

    // ── Save ─────────────────────────────────────────────────

    private func save() async {
        isSaving = true
        let finalDeadline       = hasDeadline ? deadline : nil
        let finalReminderOffset = (hasDeadline && hasReminder) ? reminderOffset.rawValue : nil
        let finalReminderDate   = (!hasDeadline && hasReminder) ? reminderDateTime : nil

        if let existing = editItem {
            var updated = existing
            updated.title             = title.trimmingCharacters(in: .whitespaces)
            updated.notes             = notes.isEmpty ? nil : notes
            updated.listDate          = listDate
            updated.deadline          = finalDeadline
            updated.reminderOffset    = finalReminderOffset
            updated.reminderDate      = finalReminderDate
            updated.recurrence        = recurrence
            updated.priority          = priority
            updated.recurrenceEndDate = hasEndDate ? DateUtils.string(from: recurrenceEndDate) : nil
            updated.movedToDate       = existing.movedToDate

            if editEntireSeries {
                await todoVM.updateSeries(updated)
            } else {
                await todoVM.updateItem(updated)
            }
        } else {
            await todoVM.addItem(
                title:              title.trimmingCharacters(in: .whitespaces),
                notes:              notes.isEmpty ? nil : notes,
                listDate:           listDate,
                deadline:           finalDeadline,
                reminderOffset:     finalReminderOffset,
                reminderDate:       finalReminderDate,
                recurrence:         recurrence,
                priority:           priority,
                recurrenceEndDate:  hasEndDate ? DateUtils.string(from: recurrenceEndDate) : nil
            )
        }
        isSaving = false
        dismiss()
    }
}
