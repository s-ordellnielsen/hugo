import SwiftUI

// MARK: - Hugo Theme Tokens

/// Shared layout values for recurring Hugo interface elements.
enum HugoLayout {
    enum Spacing {
        static let tight: CGFloat = 4
        static let small: CGFloat = 6
        static let compact: CGFloat = 8
        static let regular: CGFloat = 12
        static let spacious: CGFloat = 16
        static let roomy: CGFloat = 20
        static let card: CGFloat = 24
        static let section: CGFloat = 32
    }

    enum CornerRadius {
        static let compactCard: CGFloat = 24
        static let card: CGFloat = 32
    }

    enum Size {
        static let entryIcon: CGFloat = 32
        static let categoryIcon: CGFloat = 48
        static let categoryIconTile: CGFloat = 128
        static let prominentSymbol: CGFloat = 64
        static let labelReservedIconWidth: CGFloat = 24
        static let symbolPickerMinimumCellWidth: CGFloat = 70
        static let monthlyProgressDiameter: CGFloat = 360
        static let categoryProgressHeight: CGFloat = 56
        static let durationPickerComponentWidth: CGFloat = 70
        static let durationPickerHeight: CGFloat = 216
        static let addEntryCompactSheetHeight: CGFloat = 300
    }

    enum Typography {
        static let monthlyProgressHeroSize: CGFloat = 80
        static let eyebrowTracking: CGFloat = 1.5
    }

    enum Opacity {
        static let selectedSymbol: Double = 0.12
    }
}

extension Color {
    /// Hugo's signature opt-in accent color (currently System Teal).
    /// Enables: `.tint(.hugoAccent)`, `Color.hugoAccent`.
    static var hugoAccent: Color { .mint }
}

extension ShapeStyle where Self == Color {
    /// Hugo's signature opt-in accent color (currently System Teal).
    /// Enables: `.foregroundStyle(.hugoAccent)`, `.background(.hugoAccent)`.
    static var hugoAccent: Color { Color.hugoAccent }
}
