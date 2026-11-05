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

    /// "23 hours", "23 hours, 15 min" or "45 min" (Danish: "23 timer 15 min").
    /// Hours are a full word and minutes are always "min". Seconds are dropped,
    /// zero minutes are left out, and zero is "0 hours". Negative values count as zero.
    static func hoursString(from duration: TimeInterval, locale: Locale = .current) -> String {
        let wholeMinutes = Int(max(duration, 0) / 60)
        let hours = wholeMinutes / 60
        let minutes = wholeMinutes % 60

        var hoursStyle = Duration.UnitsFormatStyle(
            allowedUnits: [.hours], width: .wide, zeroValueUnits: .show(length: 1))
        hoursStyle.locale = locale
        let hoursText = Duration.seconds(hours * 3_600).formatted(hoursStyle)
        guard minutes > 0 else { return hoursText }

        // LocalizedStringResource picks the catalog language from `locale`;
        // String(localized:locale:) would not.
        let minutesText = String(
            localized: LocalizedStringResource(
                "duration.minutesShort", defaultValue: "\(minutes) min", locale: locale,
                comment: "Minutes in a short duration, such as the 15 min in 23 hours, 15 min. No period after min."))
        guard hours > 0 else { return minutesText }

        return String(
            localized: LocalizedStringResource(
                "duration.hoursAndMinutes", defaultValue: "\(hoursText), \(minutesText)", locale: locale,
                comment:
                    "A duration with hours and minutes, such as 23 hours, 15 min. The first argument is the hours (23 hours), the second the minutes (15 min)."
            ))
    }
}
