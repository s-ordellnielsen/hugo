import SwiftUI

/// Two views side by side on wide screens and stacked otherwise. The leading
/// view comes first in both layouts, so reading order and VoiceOver order
/// match, and the view tree stays the same when the layout switches (state in
/// either view survives a rotation).
struct AdaptiveTwoColumnStack<Leading: View, Trailing: View>: View {
    /// The leading column's width when side by side.
    let leadingWidth: CGFloat
    /// Whether text columns are capped at the readable width, as
    /// `.padding()` followed by `.readableContentWidth()` did: the stacked
    /// layout as a whole (inset included), and the trailing column when side
    /// by side.
    var capsAtReadableWidth = false
    /// Padding around the stack, like `.padding()`. It is applied inside the
    /// cap, so a stacked screen caps at the same total width as before.
    var inset: CGFloat = 0
    var spacing: CGFloat = HugoLayout.Spacing.section
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var readableWidth = HugoLayout.Size.readableContentWidth
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let isSideBySide = TwoColumnBreakpoint.usesTwoColumns(
            availableWidth: availableWidth - 2 * inset, minimumWidth: HugoLayout.Size.twoColumnMinimumWidth,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        let layout =
            isSideBySide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(spacing: 0))
        layout {
            leading
                .frame(width: isSideBySide ? leadingWidth : nil)
            trailing
                .frame(maxWidth: isSideBySide && capsAtReadableWidth ? readableWidth : .infinity)
        }
        .padding(inset)
        .frame(maxWidth: maxWidth(isSideBySide: isSideBySide))
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
    }

    private func maxWidth(isSideBySide: Bool) -> CGFloat {
        guard capsAtReadableWidth else { return .infinity }
        return isSideBySide ? leadingWidth + spacing + readableWidth + 2 * inset : readableWidth
    }
}
