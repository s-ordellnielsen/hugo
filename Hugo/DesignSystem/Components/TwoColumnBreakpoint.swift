import CoreGraphics

/// Whether a screen has room for two columns side by side.
nonisolated enum TwoColumnBreakpoint {
    /// Two columns when the available width reaches `minimumWidth`, never at
    /// accessibility text sizes (they need the whole width for one column).
    static func usesTwoColumns(
        availableWidth: CGFloat, minimumWidth: CGFloat, isAccessibilitySize: Bool
    ) -> Bool {
        guard availableWidth.isFinite, minimumWidth.isFinite, !isAccessibilitySize else { return false }
        return availableWidth >= minimumWidth
    }
}
