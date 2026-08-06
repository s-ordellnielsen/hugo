import SwiftUI

/// The app's complete motion vocabulary. Four tokens, all under 400 ms.
enum Motion {
    /// Press feedback and other sub-200 ms acknowledgements.
    static let feedback: Animation = .easeOut(duration: 0.16)
    /// Value changes: numbers, swapped rows, recalculated totals.
    static let value: Animation = .smooth(duration: 0.25)
    /// Elements entering or leaving the layout.
    static let presence: Animation = .smooth(duration: 0.3)
    /// The progress fill — the one place a little physics is warranted.
    static let progress: Animation = .spring(duration: 0.6, bounce: 0.15)
}

extension View {
    /// Applies motion while respecting the user's Reduce Motion preference.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.2) : animation, value: value)
    }
}
