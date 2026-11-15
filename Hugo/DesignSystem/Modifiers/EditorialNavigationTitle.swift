import SwiftUI

/// Shows the navigation title in the app's serif style. The title is also set
/// with `navigationTitle`, so the back-button menu and VoiceOver still read it.
/// Use it on screens that show the user's own content, on tab roots and on
/// sheets that start an action. Settings sub-pages and small pickers keep the
/// system title.
extension View {
    func editorialNavigationTitle(_ titleKey: LocalizedStringResource) -> some View {
        editorialNavigationTitle(String(localized: titleKey))
    }

    @_disfavoredOverload
    func editorialNavigationTitle<Title: StringProtocol>(_ title: Title) -> some View {
        let title = String(title)
        return
            self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EditorialNavigationTitle(title: title)
                }
            }
    }
}

private struct EditorialNavigationTitle: View {
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
