import SwiftUI

struct DurationWheelPicker: View {
    @Binding var duration: TimeInterval
    let minuteInterval: Int
    let maxDuration: TimeInterval

    private var maximumMinutes: Int { max(0, Int(maxDuration / 60)) }
    private var hourValues: [Int] { Array(0...max(0, maximumMinutes / 60)) }
    private var minuteValues: [Int] { Array(stride(from: 0, through: 59, by: minuteInterval)) }

    private var selectedHours: Binding<Int> {
        Binding(
            get: { clampedHours },
            set: { update(hours: $0, minutes: clampedMinutes) }
        )
    }

    private var selectedMinutes: Binding<Int> {
        Binding(
            get: { clampedMinutes },
            set: { update(hours: clampedHours, minutes: $0) }
        )
    }

    private var clampedHours: Int {
        min(maximumMinutes / 60, max(0, Int(max(0, duration) / 3600)))
    }

    private var clampedMinutes: Int {
        let raw = Int(max(0, duration).truncatingRemainder(dividingBy: 3600) / 60)
        return min(59, max(0, (raw / minuteInterval) * minuteInterval))
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("entry.duration.hours", selection: selectedHours) {
                ForEach(hourValues, id: \.self) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Text(":")
                .font(.title2.monospacedDigit())

            Picker("entry.duration.minutes", selection: selectedMinutes) {
                ForEach(minuteValues, id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .accessibilityElement(children: .contain)
        .onAppear { normalize() }
    }

    private func update(hours: Int, minutes: Int) {
        let candidate = TimeInterval(hours * 3600 + minutes * 60)
        duration = min(maxDuration, max(0, candidate))
    }

    private func normalize() {
        update(hours: clampedHours, minutes: clampedMinutes)
    }
}
