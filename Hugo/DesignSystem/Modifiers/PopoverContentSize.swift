import SwiftUI

extension View {
    /// Gives popover content a size. A popover sizes itself to its content's
    /// ideal size, and a navigation stack with a form or scroll view has none.
    /// When the popover shows as a sheet (iPhone, narrow iPad windows), the
    /// sheet proposes its own size and these values do nothing.
    func popoverContentSize() -> some View {
        frame(idealWidth: HugoLayout.Size.popoverWidth, idealHeight: HugoLayout.Size.popoverHeight)
    }
}
