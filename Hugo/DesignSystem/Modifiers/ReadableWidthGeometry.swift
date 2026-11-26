import CoreGraphics

/// The horizontal content margin that keeps a list's rows at a readable width.
nonisolated enum ReadableWidthGeometry {
    /// The margin for each side of a list `containerWidth` wide, so its rows are
    /// at most `maxWidth` wide. `nil` when the list's own margin is already
    /// enough, so the system default stays in place on narrow screens.
    static func listMargin(
        containerWidth: CGFloat, maxWidth: CGFloat, minimumMargin: CGFloat = 20
    ) -> CGFloat? {
        guard containerWidth.isFinite, maxWidth.isFinite else { return nil }
        let margin = (containerWidth - maxWidth) / 2
        return margin > minimumMargin ? margin : nil
    }
}
