import SwiftUI

struct EditorialNavigationTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.headline, design: .serif, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            // Like the system navigation bar: stop growing at the largest
            // standard size, and show the title enlarged on long-press.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
    }
}
