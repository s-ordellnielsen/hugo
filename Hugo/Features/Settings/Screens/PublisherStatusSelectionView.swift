import SwiftUI

struct PublisherStatusSelectionView: View {
    @AppStorage(UserDefaultsKeys.publisherStatus) var currentStatus: String = ""

    var body: some View {
        List {
            CurrentPublisherStatusView(currentStatus: currentStatus)

            Section {
                PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .list)
            }
        }
        .readableListWidth()
        .editorialNavigationTitle("account.page.publisherstatus.title")
    }
}

#Preview {
    PublisherStatusSelectionView()
}
