import Foundation

nonisolated enum ServiceDurationFormatter {
    static func string(from duration: TimeInterval) -> String {
        let clamped = max(duration, 0)
        let hours = Int(clamped / 3600)
        let minutes = Int(clamped.truncatingRemainder(dividingBy: 3600) / 60)
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func accessibilityString(from duration: TimeInterval, locale: Locale = .current) -> String {
        let clamped = max(duration, 0)
        let hours = Int(clamped / 3600)
        let minutes = Int(clamped.truncatingRemainder(dividingBy: 3600) / 60)
        var style = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)
        style.locale = locale
        return Duration.seconds(hours * 3600 + minutes * 60).formatted(style)
    }
}
