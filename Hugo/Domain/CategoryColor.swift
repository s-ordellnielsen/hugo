import Foundation

/// A category color as the user chose it: a hue and a tone, both 0...1.
/// The same choice gives a deeper color in light mode and a lighter one in
/// dark mode, and is nudged until it stands out from the background, so it
/// stays visible in both. A category without one is Automatic and uses the
/// accent color. See "Category color" in CONTEXT.md.
nonisolated struct CategoryColor: Hashable, Sendable {
    enum Appearance: Sendable {
        case light
        case dark
    }

    /// The color to draw, as HSB channels from 0 to 1.
    struct Components: Equatable, Sendable {
        let hue: Double
        let saturation: Double
        let brightness: Double
    }

    /// The lowest contrast ratio against any light-mode reference background.
    /// Apple's orange, green and mint measure about 1.9-2.0 against
    /// systemGroupedBackground, so 1.8 allows system-like colors and still
    /// darkens near-white ones.
    static let lightMinimumContrast = 1.8

    /// The lowest contrast ratio against any dark-mode reference background.
    static let darkMinimumContrast = 2.0

    let hue: Double
    let tone: Double

    /// Clamps both values into 0...1. Non-finite values become 0.
    init(hue: Double, tone: Double) {
        self.hue = Self.clamped(hue)
        self.tone = Self.clamped(tone)
    }

    /// Reads the stored fields. Nil (Automatic) unless both are set, finite
    /// and within 0...1.
    init?(storedHue: Double?, storedTone: Double?) {
        guard let storedHue, let storedTone, storedHue.isFinite, storedTone.isFinite,
            (0...1).contains(storedHue), (0...1).contains(storedTone)
        else { return nil }
        self.init(hue: storedHue, tone: storedTone)
    }

    /// The HSB components for one appearance, nudged away from the reference
    /// backgrounds when the contrast would be below that appearance's minimum
    /// contrast.
    func components(for appearance: Appearance) -> Components {
        switch appearance {
        case .light:
            let saturation = 0.55 + 0.35 * tone
            var brightness = 1.00 - 0.20 * tone
            while brightness > 0.2,
                !Self.meetsFloor(
                    hue: hue, saturation: saturation, brightness: brightness, backgrounds: Self.lightBackgrounds,
                    minimumContrast: Self.lightMinimumContrast)
            {
                brightness -= 0.02
            }
            return Components(hue: hue, saturation: saturation, brightness: brightness)
        case .dark:
            var saturation = 0.12 + 0.68 * tone
            var brightness = 1.00 - 0.10 * tone
            while !Self.meetsFloor(
                hue: hue, saturation: saturation, brightness: brightness, backgrounds: Self.darkBackgrounds,
                minimumContrast: Self.darkMinimumContrast)
            {
                if brightness < 1.0 {
                    brightness = min(1.0, brightness + 0.02)
                } else if saturation > 0 {
                    saturation = max(0, saturation - 0.02)
                } else {
                    break
                }
            }
            return Components(hue: hue, saturation: saturation, brightness: brightness)
        }
    }

    // MARK: - Color math

    /// Luminances of the light-mode reference backgrounds: systemBackground
    /// and systemGroupedBackground.
    static let lightBackgrounds: [Double] = [
        relativeLuminance(red: 255 / 255, green: 255 / 255, blue: 255 / 255),
        relativeLuminance(red: 242 / 255, green: 242 / 255, blue: 247 / 255),
    ]

    /// Luminances of the dark-mode reference backgrounds: black,
    /// secondarySystemGroupedBackground and tertiarySystemGroupedBackground.
    static let darkBackgrounds: [Double] = [
        relativeLuminance(red: 0, green: 0, blue: 0),
        relativeLuminance(red: 28 / 255, green: 28 / 255, blue: 30 / 255),
        relativeLuminance(red: 44 / 255, green: 44 / 255, blue: 46 / 255),
    ]

    /// Standard HSB-to-RGB conversion, each channel 0...1.
    static func rgb(_ c: Components) -> (red: Double, green: Double, blue: Double) {
        let scaled = c.hue * 6
        let sector = Int(floor(scaled)) % 6
        let f = scaled - floor(scaled)
        let p = c.brightness * (1 - c.saturation)
        let q = c.brightness * (1 - f * c.saturation)
        let t = c.brightness * (1 - (1 - f) * c.saturation)
        switch sector {
        case 0: return (c.brightness, t, p)
        case 1: return (q, c.brightness, p)
        case 2: return (p, c.brightness, t)
        case 3: return (p, q, c.brightness)
        case 4: return (t, p, c.brightness)
        default: return (c.brightness, p, q)
        }
    }

    /// WCAG relative luminance of an sRGB color with channels 0...1.
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio between two relative luminances. Order-independent.
    static func contrastRatio(_ a: Double, _ b: Double) -> Double {
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func meetsFloor(
        hue: Double, saturation: Double, brightness: Double, backgrounds: [Double], minimumContrast: Double
    ) -> Bool {
        let rgbValue = rgb(Components(hue: hue, saturation: saturation, brightness: brightness))
        let luminance = relativeLuminance(red: rgbValue.red, green: rgbValue.green, blue: rgbValue.blue)
        return backgrounds.allSatisfy { contrastRatio(luminance, $0) >= minimumContrast }
    }

    private static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
