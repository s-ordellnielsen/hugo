import SwiftUI
import UIKit

/// A purpose-built duration picker backed by a single native `UIPickerView`
/// with two components (hours, minutes). `UIPickerView` — unlike
/// `UIDatePicker` — is not a repurposed time-of-day control; it is the
/// generic wheel-selection primitive that `UIDatePicker` itself is built on.
/// Using it directly here gives a single, continuous selection highlight
/// spanning both components, which two separate SwiftUI `Picker`s cannot
/// produce (each draws its own highlight).
private let durationPickerComponentWidth: CGFloat = 70

struct DurationWheelPicker: View {
    @Binding var duration: TimeInterval
    let minuteInterval: Int
    let maxDuration: TimeInterval

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            DurationPickerRepresentable(duration: $duration, minuteInterval: minuteInterval, maxDuration: maxDuration)
                .frame(width: durationPickerComponentWidth * 2, height: 216)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("entry.duration.label"))
    }
}

private struct DurationPickerRepresentable: UIViewRepresentable {
    @Binding var duration: TimeInterval
    let minuteInterval: Int
    let maxDuration: TimeInterval

    private var interval: Int { [1, 5, 15].contains(minuteInterval) ? minuteInterval : 1 }
    private var maxHours: Int { max(0, Int(maxDuration / 3600)) }

    func makeCoordinator() -> Coordinator {
        Coordinator(duration: $duration, maxDuration: maxDuration, interval: interval, maxHours: maxHours)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        context.coordinator.select(in: picker, animated: false)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        let coordinator = context.coordinator
        let optionsChanged = coordinator.interval != interval || coordinator.maxHours != maxHours
        coordinator.interval = interval
        coordinator.maxHours = maxHours
        coordinator.maxDuration = maxDuration
        if optionsChanged {
            picker.reloadAllComponents()
        }

        // SwiftUI re-invokes `updateUIView` on nearly every render pass of the
        // enclosing view hierarchy, not only when `duration` changes. Forcing
        // `selectRow` unconditionally would fight an in-progress scroll/drag
        // gesture and snap the wheel back to the last committed value. Only
        // re-sync the picker's selection when `duration` was changed from
        // *outside* this control (e.g. programmatic reset) — not when the
        // change originated from the picker's own `didSelectRow`.
        guard abs(duration - coordinator.lastAppliedDuration) > 0.001 else { return }
        coordinator.select(in: picker, animated: context.transaction.animation != nil)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var duration: Binding<TimeInterval>
        var maxDuration: TimeInterval
        var interval: Int
        var maxHours: Int

        /// The duration value this coordinator last applied to the picker,
        /// either by reading it in `select(in:animated:)` or by writing it in
        /// `didSelectRow`. Used to distinguish an externally-driven change to
        /// `duration` from a change the picker itself just produced.
        private(set) var lastAppliedDuration: TimeInterval

        init(duration: Binding<TimeInterval>, maxDuration: TimeInterval, interval: Int, maxHours: Int) {
            self.duration = duration
            self.maxDuration = maxDuration
            self.interval = interval
            self.maxHours = maxHours
            self.lastAppliedDuration = duration.wrappedValue
        }

        private var hours: Int {
            min(maxHours, Int(max(0, duration.wrappedValue) / 3600))
        }

        private var minuteOptions: [Int] {
            let remainingSeconds = maxDuration - TimeInterval(hours * 3600)
            let ceiling = hours >= maxHours ? max(0, Int(remainingSeconds / 60)) : 59
            return Array(stride(from: 0, through: ceiling, by: interval))
        }

        private var minutes: Int {
            let rawMinutes = Int(max(0, duration.wrappedValue).truncatingRemainder(dividingBy: 3600) / 60)
            let snapped = (rawMinutes / interval) * interval
            return min(minuteOptions.last ?? 0, snapped)
        }

        func select(in picker: UIPickerView, animated: Bool) {
            picker.selectRow(hours, inComponent: 0, animated: animated)
            let minuteRow = minuteOptions.firstIndex(of: minutes) ?? 0
            picker.selectRow(minuteRow, inComponent: 1, animated: animated)
            lastAppliedDuration = duration.wrappedValue
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? maxHours + 1 : minuteOptions.count
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            durationPickerComponentWidth
        }

        func pickerView(
            _ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?
        ) -> UIView {
            let label = view as? UILabel ?? UILabel()
            let value = component == 0 ? row : minuteOptions[row]
            label.text = String(format: "%02d", value)
            label.font = .preferredFont(forTextStyle: .title2)
            label.textAlignment = .center
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let newHours = component == 0 ? row : hours
            var newMinutes = component == 1 ? minuteOptions[row] : minutes

            if component == 0 {
                let remainingSeconds = maxDuration - TimeInterval(newHours * 3600)
                let ceiling = newHours >= maxHours ? max(0, Int(remainingSeconds / 60)) : 59
                let options = Array(stride(from: 0, through: ceiling, by: interval))
                newMinutes = min(options.last ?? 0, newMinutes)
                pickerView.reloadComponent(1)
                let minuteRow = options.firstIndex(of: newMinutes) ?? 0
                pickerView.selectRow(minuteRow, inComponent: 1, animated: false)
            }

            let candidate = TimeInterval(newHours * 3600 + newMinutes * 60)
            let clamped = min(maxDuration, max(0, candidate))
            duration.wrappedValue = clamped
            lastAppliedDuration = clamped
        }
    }
}

#Preview("24 hour max") {
    @Previewable @State var duration: TimeInterval = 5_400
    Form {
        Section("entry.duration.label") {
            DurationWheelPicker(duration: $duration, minuteInterval: 5, maxDuration: 24 * 60 * 60)
        }
    }
}

#Preview("Large max (backfill)") {
    @Previewable @State var duration: TimeInterval = 5_400
    Form {
        Section("entry.duration.label") {
            DurationWheelPicker(duration: $duration, minuteInterval: 15, maxDuration: 100 * 60 * 60)
        }
    }
}
