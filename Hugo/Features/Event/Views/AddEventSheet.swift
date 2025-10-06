//
//  AddEventSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

import SwiftUI

struct AddEventSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var date: Date = (Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) ?? Date())
    @State var duration: Date = (Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) ?? Date())
    
    @State var includeTime: Bool = false
    
    var submitAction: (_ date: Date, _ hours: Int) -> Void = { date,hours in }
    
    var body: some View {
        NavigationStack {
        Form {
            Section("Duration") {
                DatePicker("Duration", selection: $duration, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            
            Section {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                Toggle("Time", isOn: $includeTime.animation())
                if includeTime {
                    DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                        .transition(.identity.animation(.easeInOut(duration: 0.2)))
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
        }
        .navigationTitle(String("Add Event"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                }
                label: {
                    Label("Dismiss", systemImage: "xmark")
                }
            }
            ToolbarItem {
                Button(action: submitForm) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .disabled(isDurationZero())
            }
        }
        }
    }
    
    private func submitForm() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: duration)
        
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        let durationInSeconds = hours * 3600 + minutes * 60
        
        submitAction(date, durationInSeconds)
        dismiss()
    }
    
    func isDurationZero() -> Bool {
        let calendar = Calendar.current
        let durationComponents = calendar.dateComponents([.hour, .minute], from: duration)
        return (durationComponents.hour == 0 && durationComponents.minute == 0)
    }}

#Preview {
    AddEventSheet()
}
