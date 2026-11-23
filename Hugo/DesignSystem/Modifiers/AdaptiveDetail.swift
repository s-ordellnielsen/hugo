import SwiftUI

/// How a detail for one existing item is shown. Regular width gets an inspector
/// beside the content, compact width (and an unknown size class) gets a sheet.
nonisolated enum DetailPresentation: Equatable, Sendable {
    case inspector
    case sheet

    static func presentation(for sizeClass: UserInterfaceSizeClass?) -> DetailPresentation {
        sizeClass == .regular ? .inspector : .sheet
    }
}

extension View {
    /// Shows `content` for the item in `item`: an inspector beside the view at
    /// regular width, a sheet at compact width. Setting `item` to `nil` closes it.
    /// The inspector keeps the last item while it animates closed.
    func adaptiveDetail<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(AdaptiveDetailModifier(item: item, makeContent: content))
    }
}

private struct AdaptiveDetailModifier<Item: Identifiable, DetailContent: View>: ViewModifier {
    @Binding var item: Item?
    let makeContent: (Item) -> DetailContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var lastItem: Item?

    func body(content: Content) -> some View {
        switch DetailPresentation.presentation(for: horizontalSizeClass) {
        case .inspector:
            content
                .inspector(isPresented: isInspectorPresented) {
                    if let shown = item ?? lastItem {
                        makeContent(shown)
                    }
                }
                .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
                .onChange(of: item?.id) {
                    if let item {
                        lastItem = item
                    }
                }
        case .sheet:
            content
                .sheet(item: $item) { item in
                    makeContent(item)
                        .presentationDetents([.medium, .large])
                }
        }
    }

    private var isInspectorPresented: Binding<Bool> {
        Binding(
            get: { item != nil },
            set: { isPresented in
                if !isPresented {
                    item = nil
                }
            }
        )
    }
}
