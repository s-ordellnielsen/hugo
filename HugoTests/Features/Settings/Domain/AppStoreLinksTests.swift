import Foundation
import Testing

@testable import Hugo

struct AppStoreLinksTests {
    @Test
    func buildsTheProductAndReviewPages() throws {
        let links = try #require(AppStoreLinks(appleID: "6754619142"))

        #expect(links.productURL.absoluteString == "https://apps.apple.com/app/id6754619142")
        #expect(links.reviewURL.absoluteString == "https://apps.apple.com/app/id6754619142?action=write-review")
    }

    @Test(arguments: [nil, "", "abc", "675 4619142", "$(APP_STORE_ID)"] as [String?])
    func rejectsMissingOrMalformedIDs(appleID: String?) {
        #expect(AppStoreLinks(appleID: appleID) == nil)
    }
}
