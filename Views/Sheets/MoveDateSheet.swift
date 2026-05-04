import SwiftUI
import Combine

struct MoveDateSheet: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    let item: TodoItem
    @State private var targetDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Move \"\(item.title)\" to") {
                    DatePicker("New Date", selection: $targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Move Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        let dateString = DateUtils.string(from: targetDate)
                        Task {
                            await todoVM.move(item, to: dateString)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            // Default to tomorrow if item is today, otherwise today
            let td = DateUtils.today()
            let defaultTarget = item.listDate == td
                ? DateUtils.date(from: DateUtils.tomorrow()) ?? Date()
                : Date()
            targetDate = defaultTarget
        }
    }
}
