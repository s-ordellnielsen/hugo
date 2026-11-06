import Foundation

/// What VoiceOver says for one row of the duration wheel: the number with its
/// unit, such as "1 hour" or "30 minutes" ("1 time", "30 minutter" in Danish).
nonisolated enum DurationWheelAccessibility {
    static func hoursLabel(_ hours: Int, locale: Locale = .current) -> String {
        label(seconds: hours * 3_600, unit: .hours, locale: locale)
    }

    static func minutesLabel(_ minutes: Int, locale: Locale = .current) -> String {
        label(seconds: minutes * 60, unit: .minutes, locale: locale)
    }

    private static func label(seconds: Int, unit: Duration.UnitsFormatStyle.Unit, locale: Locale) -> String {
        var style = Duration.UnitsFormatStyle(
            allowedUnits: [unit],
            width: .wide,
            zeroValueUnits: .show(length: 1)
        )
        style.locale = locale
        return Duration.seconds(seconds).formatted(style)
    }
}
