import SwiftUI

extension View {
    /// Caps content inside a `ScrollView` at a readable width and centers it.
    /// Put it on the scroll view's content, not on the scroll view, so the
    /// whole screen still scrolls and the indicator stays at the edge.
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidth())
    }

    /// Caps the rows of a `List` or `Form` at a readable width by widening its
    /// horizontal content margins. Put it on the `List` or `Form`.
    func readableListWidth() -> some View {
        modifier(ReadableListWidth())
    }
}

private struct ReadableContentWidth: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var maxWidth = HugoLayout.Size.readableContentWidth

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

private struct ReadableListWidth: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var maxWidth = HugoLayout.Size.readableContentWidth
    @State private var container = ReadableListContainer()

    func body(content: Content) -> some View {
        let margins = ReadableWidthGeometry.listMargins(
            containerWidth: container.width, leadingInset: container.leadingInset,
            trailingInset: container.trailingInset, maxWidth: maxWidth)
        content
            .contentMargins(.leading, margins?.leading, for: .scrollContent)
            .contentMargins(.trailing, margins?.trailing, for: .scrollContent)
            .onGeometryChange(for: ReadableListContainer.self) { proxy in
                ReadableListContainer(
                    width: proxy.size.width, leadingInset: proxy.safeAreaInsets.leading,
                    trailingInset: proxy.safeAreaInsets.trailing)
            } action: { newValue in
                container = newValue
            }
    }
}

/// The list's width and the safe-area insets beside it (the iPad sidebar is
/// a leading inset).
nonisolated private struct ReadableListContainer: Equatable, Sendable {
    var width: CGFloat = 0
    var leadingInset: CGFloat = 0
    var trailingInset: CGFloat = 0
}
