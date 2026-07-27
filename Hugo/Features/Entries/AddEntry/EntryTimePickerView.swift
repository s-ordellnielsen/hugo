import SwiftUI

struct EntryTimePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date?
    @State private var selectedDate: Date

    init(date: Binding<Date?>) {
        _date = date
        _selectedDate = State(initialValue: date.wrappedValue ?? .now)
    }

    var body: some View {
        NavigationStack {
            DatePicker("entry.add.time.select.label", selection: $selectedDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .navigationTitle("entry.add.time.select.label")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem {
                        Button("navigation.done", systemImage: "checkmark") {
                            date = selectedDate
                            dismiss()
                        }
                    }
                    if date != nil {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("navigation.clear", systemImage: "trash") {
                                date = nil
                                dismiss()
                            }
                        }
                    }
                }
        }
    }
}
