import SwiftUI

struct EntryDurationPicker: View {
    @Binding var duration: TimeInterval
    let minuteInterval: Int
    let maxDuration: TimeInterval

    var body: some View {
        DurationWheelPicker(duration: $duration, minuteInterval: minuteInterval, maxDuration: maxDuration)
            .overlay(alignment: .topLeading) {
                Label("entry.duration.label", systemImage: "clock")
                    .padding(.top, 8)
            }
    }
}
