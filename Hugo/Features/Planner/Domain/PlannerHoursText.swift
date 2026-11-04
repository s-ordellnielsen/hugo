import Foundation

nonisolated enum PlannerHoursText {
    /// A short duration for a calendar cell, such as "2h", "1h 30m" or "45m".
    /// Seconds are dropped.
    static func short(_ seconds: TimeInterval, locale: Locale = .current) -> String {
        let wholeMinutes = Int(max(seconds, 0) / 60)
        var style = Duration.UnitsFormatStyle(
            allowedUnits: [.hours, .minutes], width: .narrow, zeroValueUnits: .hide)
        style.locale = locale
        return Duration.seconds(wholeMinutes * 60).formatted(style)
    }
}
