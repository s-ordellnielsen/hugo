import Foundation
import Testing

@testable import Hugo

struct SupportEmailLinkTests {
    @Test
    func emptyAddressReturnsNil() {
        #expect(SupportEmailLink.url(address: "", subject: "Feedback") == nil)
    }

    @Test
    func buildsMailtoLinkWithEncodedSubject() throws {
        let subject = "Feedback på Hugo (1.0, build 125)"
        let url = try #require(SupportEmailLink.url(address: "app@example.com", subject: subject))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(url.scheme == "mailto")
        #expect(components.path == "app@example.com")
        #expect(components.queryItems?.first(where: { $0.name == "subject" })?.value == subject)
        #expect(!url.absoluteString.contains(" "))
    }
}
