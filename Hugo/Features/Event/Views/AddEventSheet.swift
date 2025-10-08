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
    @State var time: Date? = nil
    @State var duration: Date = (Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) ?? Date())
    
    @State var showTimeSheet: Bool = false
    
    @State var includeTime: Bool = false
    
    var submitAction: (_ date: Date, _ hours: Int) -> Void = { date,hours in }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    VStack(alignment: .center) {
                        DatePicker("Duration", selection: $duration, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    Button {
                        showTimeSheet = true
                    } label: {
                        HStack {
                            Text("Time")
                            Spacer()
                            if time == nil {
                                Text("Select Time")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text((time != nil) ? formatTime(time ?? Date()) : "Error")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .sheet(isPresented: $showTimeSheet) {
                        SelectTimeSheet(date: $time, showTimeSheet: $showTimeSheet)
                            .presentationDetents([.height(300)])
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: submitForm) {
                    Label("Add Event", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .controlSize(.extraLarge)
                .frame(maxWidth: .infinity)
                .padding()
                .disabled(isDurationZero())
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
            }
        }
    }
    
    private func submitForm() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        if time != nil {
            components.hour = calendar.component(.hour, from: time!)
            components.minute = calendar.component(.minute, from: time!)
        }
        
        let newDate = calendar.date(from: components)!
        
        submitAction(newDate, durationInSeconds())
        dismiss()
    }
    
    private func isDurationZero() -> Bool {
        withAnimation {
            let calendar = Calendar.current
            let durationComponents = calendar.dateComponents([.hour, .minute], from: duration)
            return (durationComponents.hour == 0 && durationComponents.minute == 0)
        }
    }
    
    private func durationInSeconds() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: duration)
        
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        return hours * 3600 + minutes * 60
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isDateAtMidnight() -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return components.hour == 0 && components.minute == 0
    }
    
    struct SelectTimeSheet: View {
        @Binding var date: Date?
        @Binding var showTimeSheet: Bool
        
        @State private var selectedDate: Date = Date()
        
        var body: some View {
            NavigationStack {
                DatePicker("Time", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .navigationBarTitle("Select Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem {
                            Button {
                                date = selectedDate
                                showTimeSheet = false
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                        }
                        if date != nil {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    date = nil
                                    showTimeSheet = false
                                } label: {
                                    Label("Clear", systemImage: "trash")
                                }
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    AddEventSheet()
}
