//
//  EntryListDurationPicker.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

extension EntryList {
    struct DurationPicker: View {
        @Environment(\.modelContext) private var context
        
        @Binding var duration: TimeInterval
        
        @State var durationAsDate: Date
        
        var body: some View {
            DatePicker(selection: $durationAsDate, displayedComponents: .hourAndMinute) {
                Label("entry.duration.label", systemImage: "clock")
            }
            .onChange(of: durationAsDate, updateDuration)
        }
        
        private func updateDuration() {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute, .second], from: durationAsDate)
            
            let hours: Int = (components.hour ?? 0) * 60 * 60
            let minutes: Int = (components.minute ?? 0) * 60
            let seconds: Int = components.second ?? 0
            
            duration = TimeInterval(hours + minutes + seconds)
        }
    }
}
