import Foundation

/// A rough color name for a hue, spoken by VoiceOver on the hue slider.
nonisolated enum CategoryHueName: CaseIterable, Sendable {
    case red, orange, yellow, green, teal, blue, purple, pink

    /// Hue ranges (0...1): red below 0.04 or from 0.96, orange below 0.11,
    /// yellow below 0.19, green below 0.44, teal below 0.53, blue below 0.69,
    /// purple below 0.81, pink below 0.96.
    init(hue: Double) {
        switch hue {
        case ..<0.04, 0.96...: self = .red
        case ..<0.11: self = .orange
        case ..<0.19: self = .yellow
        case ..<0.44: self = .green
        case ..<0.53: self = .teal
        case ..<0.69: self = .blue
        case ..<0.81: self = .purple
        default: self = .pink
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .red: "tracker.color.hue.red"
        case .orange: "tracker.color.hue.orange"
        case .yellow: "tracker.color.hue.yellow"
        case .green: "tracker.color.hue.green"
        case .teal: "tracker.color.hue.teal"
        case .blue: "tracker.color.hue.blue"
        case .purple: "tracker.color.hue.purple"
        case .pink: "tracker.color.hue.pink"
        }
    }
}
