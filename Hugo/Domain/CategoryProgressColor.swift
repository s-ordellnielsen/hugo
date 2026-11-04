import Foundation

/// A category's stored color, or nil when the stored channels are unset or out
/// of range. Views fall back to `.hugoAccent` for nil.
nonisolated struct CategoryProgressColor: Equatable, Sendable {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init?(hue: Double, saturation: Double, brightness: Double) {
        guard (0...1).contains(hue), (0...1).contains(saturation), (0...1).contains(brightness),
            brightness > 0
        else { return nil }
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}
