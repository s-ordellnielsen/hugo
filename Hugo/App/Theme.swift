import SwiftUI

// MARK: - Hugo Theme Tokens

extension Color {
    /// Hugo's signature opt-in accent color (currently System Teal).
    /// Enables: `.tint(.hugoAccent)`, `Color.hugoAccent`.
    static var hugoAccent: Color { .teal }
}

extension ShapeStyle where Self == Color {
    /// Hugo's signature opt-in accent color (currently System Teal).
    /// Enables: `.foregroundStyle(.hugoAccent)`, `.background(.hugoAccent)`.
    static var hugoAccent: Color { Color.hugoAccent }
}
