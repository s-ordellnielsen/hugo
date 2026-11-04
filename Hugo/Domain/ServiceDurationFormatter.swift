import Foundation

nonisolated enum ServiceDurationFormatter {
    private static let defaultAccessibilityStyle = Duration.UnitsFormatStyle(
        allowedUnits: [.hours, .minutes],
        width: .wide
    )

    /// Whole hours in `duration`, ignoring minutes and seconds. Negative values count as zero.
    static func wholeHours(from duration: TimeInterval) -> Int {
        Int(max(duration, 0) / 3_600)
    }

    /// Whole minutes left over after `wholeHours(from:)`. Negative values count as zero.
    static func remainderMinutes(from duration: TimeInterval) -> Int {
        Int(max(duration, 0).truncatingRemainder(dividingBy: 3_600) / 60)
    }

    static func string(from duration: TimeInterval) -> String {
        let hours = wholeHours(from: duration)
        let minutes = remainderMinutes(from: duration)
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func accessibilityString(from duration: TimeInterval, locale: Locale = .current) -> String {
        let hours = wholeHours(from: duration)
        let minutes = remainderMinutes(from: duration)
        let seconds = hours * 3600 + minutes * 60

        if locale == .current {
            return Duration.seconds(seconds).formatted(defaultAccessibilityStyle)
        } else {
            var style = defaultAccessibilityStyle
            style.locale = locale
            return Duration.seconds(seconds).formatted(style)
        }
    }

    /// "152 hours" or "152 hours, 30 minutes". Seconds are dropped and zero minutes are omitted.
    static func hoursString(from duration: TimeInterval, locale: Locale = .current) -> String {
        let clamped = max(duration, 0)
        let wholeMinutes = Int(clamped / 60)
        let allowedUnits: Set<Duration.UnitsFormatStyle.Unit> =
            wholeMinutes == 0 ? [.hours] : [.hours, .minutes]
        var style = Duration.UnitsFormatStyle(
            allowedUnits: allowedUnits,
            width: .wide,
            zeroValueUnits: wholeMinutes == 0 ? .show(length: 1) : .hide
        )
        style.locale = locale
        return Duration.seconds(wholeMinutes * 60).formatted(style)
    }
}
