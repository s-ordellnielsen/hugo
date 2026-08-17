import Foundation

nonisolated enum ServiceDurationFormatter {
    private static let defaultAccessibilityStyle = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .wide)

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
        let seconds = hours * 3600 + minutes * 60

        if locale == .current {
            return Duration.seconds(seconds).formatted(defaultAccessibilityStyle)
        } else {
            var style = defaultAccessibilityStyle
            style.locale = locale
            return Duration.seconds(seconds).formatted(style)
        }
    }
}
