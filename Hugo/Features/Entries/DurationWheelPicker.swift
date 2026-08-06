import SwiftUI
import UIKit

struct DurationWheelPicker: View {
    @Binding var duration: TimeInterval
    let minuteInterval: Int
    let maxDuration: TimeInterval

    var body: some View {
        DurationDatePicker(
            duration: $duration,
            minuteInterval: minuteInterval,
            maxDuration: maxDuration
        )
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("entry.duration.label"))
    }
}

private struct DurationDatePicker: UIViewRepresentable {
    @Binding var duration: TimeInterval
    let minuteInterval: Int
    let maxDuration: TimeInterval

    func makeCoordinator() -> Coordinator {
        Coordinator(duration: $duration, maxDuration: maxDuration)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = normalizedMinuteInterval
        picker.countDownDuration = normalizedDuration
        picker.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.minuteInterval = normalizedMinuteInterval
        picker.countDownDuration = normalizedDuration
        context.coordinator.maxDuration = maxDuration
    }

    private var normalizedMinuteInterval: Int {
        [1, 5, 15].contains(minuteInterval) ? minuteInterval : 1
    }

    private var normalizedDuration: TimeInterval {
        let interval = TimeInterval(normalizedMinuteInterval * 60)
        let clamped = min(max(0, duration), maxDuration)
        return (clamped / interval).rounded() * interval
    }

    final class Coordinator: NSObject {
        var duration: Binding<TimeInterval>
        var maxDuration: TimeInterval

        init(duration: Binding<TimeInterval>, maxDuration: TimeInterval) {
            self.duration = duration
            self.maxDuration = maxDuration
        }

        @objc func valueChanged(_ picker: UIDatePicker) {
            duration.wrappedValue = min(picker.countDownDuration, maxDuration)
        }
    }
}
