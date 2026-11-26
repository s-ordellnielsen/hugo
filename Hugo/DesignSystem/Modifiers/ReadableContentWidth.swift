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
    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(
                .horizontal,
                ReadableWidthGeometry.listMargin(containerWidth: containerWidth, maxWidth: maxWidth),
                for: .scrollContent
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                containerWidth = width
            }
    }
}
