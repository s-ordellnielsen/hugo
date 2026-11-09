import SwiftUI

/// Draws a category color for the current light or dark mode, or the accent
/// color for Automatic (nil). SwiftUI resolves it while drawing, so it follows
/// appearance changes without the view reading the color scheme.
nonisolated struct CategoryColorStyle: ShapeStyle {
    let color: CategoryColor?

    init(_ color: CategoryColor?) {
        self.color = color
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        guard let color else { return .hugoAccent }
        return color.color(for: CategoryColor.Appearance(environment.colorScheme))
    }
}

extension CategoryColor.Appearance {
    nonisolated init(_ colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }
}

extension CategoryColor {
    /// The SwiftUI color for one appearance. Gradients use this, because a
    /// gradient stop needs a concrete `Color`.
    nonisolated func color(for appearance: Appearance) -> Color {
        let c = components(for: appearance)
        return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness)
    }
}
