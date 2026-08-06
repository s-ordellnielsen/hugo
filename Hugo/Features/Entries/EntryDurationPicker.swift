import SwiftUI

struct EntryDurationPicker: View {
    @Binding var duration: TimeInterval
    @State private var durationDate: Date

    init(duration: Binding<TimeInterval>) {
        _duration = duration
        _durationDate = State(initialValue: Self.date(from: duration.wrappedValue))
    }

    var body: some View {
        DatePicker(
            selection: $durationDate,
            displayedComponents: .hourAndMinute
        ) {
            Label("entry.duration.label", systemImage: "clock")
        }
        .datePickerStyle(.compact)
        .onChange(of: durationDate) { _, newValue in
            duration = Self.duration(from: newValue)
        }
        .onChange(of: duration) { _, newValue in
            let newDate = Self.date(from: newValue)
            if newDate != durationDate {
                durationDate = newDate
            }
        }
    }

    private static func date(from duration: TimeInterval) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: .now)
        let wholeSeconds = max(0, Int(duration))
        components.hour = wholeSeconds / 3600
        components.minute = (wholeSeconds % 3600) / 60
        components.second = wholeSeconds % 60
        return calendar.date(from: components) ?? .now
    }

    private static func duration(from date: Date) -> TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return TimeInterval(
            (components.hour ?? 0) * 3600
                + (components.minute ?? 0) * 60
                + (components.second ?? 0)
        )
    }
}
