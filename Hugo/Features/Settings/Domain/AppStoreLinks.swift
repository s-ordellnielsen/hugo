import Foundation

/// The App Store links for Hugo, built from its Apple ID in App Store Connect
/// (the `AppStoreID` key in Info.plist).
nonisolated struct AppStoreLinks: Equatable {
    /// Hugo's page on the App Store, for sharing.
    let productURL: URL
    /// The App Store page that opens the review form directly.
    let reviewURL: URL

    /// Returns nil unless `appleID` is a non-empty string of digits.
    init?(appleID: String?) {
        guard let appleID, !appleID.isEmpty, appleID.allSatisfy(\.isASCII), appleID.allSatisfy(\.isNumber),
            let productURL = URL(string: "https://apps.apple.com/app/id\(appleID)"),
            let reviewURL = URL(string: "https://apps.apple.com/app/id\(appleID)?action=write-review")
        else {
            return nil
        }
        self.productURL = productURL
        self.reviewURL = reviewURL
    }
}
