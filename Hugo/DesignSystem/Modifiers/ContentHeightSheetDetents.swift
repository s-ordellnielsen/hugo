import SwiftUI

/// Opens a sheet just tall enough for its content, and lets the user drag it
/// to full height. Apply it to the sheet's content view, which must have an
/// intrinsic height (a stack, not a `List`, `Form` or `ScrollView`).
/// The sheet starts at `.medium` until the content has been measured.
extension View {
    func sheetHeightFitsContent() -> some View {
        modifier(ContentHeightSheetDetents())
    }
}

private struct ContentHeightSheetDetents: ViewModifier {
    @State private var measuredHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                measuredHeight = $0
            }
            .presentationDetents(detents)
    }

    private var detents: Set<PresentationDetent> {
        guard let measuredHeight else { return [.medium] }
        return [.height(measuredHeight), .large]
    }
}
