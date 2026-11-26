import CoreGraphics

/// The horizontal content margins that keep a list's rows at a readable width.
nonisolated enum ReadableWidthGeometry {
    /// A list's leading and trailing content margins.
    struct ListMargins: Equatable, Sendable {
        let leading: CGFloat
        let trailing: CGFloat
    }

    /// Margins that center rows at most `maxWidth` wide in the part of a list
    /// `containerWidth` wide that its safe area leaves visible. The iPad's
    /// sidebar floats over the list as a leading safe-area inset, and a list's
    /// content margins replace its default margin, so each side gets its inset
    /// plus the same extra space. `nil` when the extra space would not exceed
    /// `minimumMargin`, so the system default stays in place on narrow screens.
    static func listMargins(
        containerWidth: CGFloat, leadingInset: CGFloat = 0, trailingInset: CGFloat = 0,
        maxWidth: CGFloat, minimumMargin: CGFloat = 20
    ) -> ListMargins? {
        guard containerWidth.isFinite, leadingInset.isFinite, trailingInset.isFinite, maxWidth.isFinite
        else { return nil }
        let visibleWidth = containerWidth - max(0, leadingInset) - max(0, trailingInset)
        let extra = (visibleWidth - maxWidth) / 2
        guard extra > minimumMargin else { return nil }
        return ListMargins(leading: max(0, leadingInset) + extra, trailing: max(0, trailingInset) + extra)
    }
}
