import Foundation

/// A total shown as one large number with a unit: whole hours, or whole
/// minutes when the total is more than zero but under one hour, so 45 minutes
/// shows as "45 min" and not "0". Seconds are dropped and negative values
/// count as zero, as in `ServiceDurationFormatter.hoursString(from:locale:)`.
nonisolated enum HeadlineDuration: Equatable, Sendable {
    case hours(Int)
    case minutes(Int)

    init(seconds: TimeInterval) {
        let wholeMinutes = Int(max(seconds, 0) / 60)
        self = (1..<60).contains(wholeMinutes) ? .minutes(wholeMinutes) : .hours(wholeMinutes / 60)
    }

    /// The number to show.
    var value: Int {
        switch self {
        case .hours(let hours): hours
        case .minutes(let minutes): minutes
        }
    }

    /// The total as VoiceOver should read it, such as "45 minutes" or
    /// "12 hours" (Danish "45 minutter", "12 timer").
    func spokenText(locale: Locale = .current) -> String {
        switch self {
        case .hours(let hours):
            ServiceDurationFormatter.hoursString(from: TimeInterval(hours) * 3_600, locale: locale)
        case .minutes(let minutes):
            ServiceDurationFormatter.accessibilityString(from: TimeInterval(minutes) * 60, locale: locale)
        }
    }
}
