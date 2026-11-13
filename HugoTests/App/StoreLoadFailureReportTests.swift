import Foundation
import Testing

@testable import Hugo

@Suite
struct StoreLoadFailureReportTests {
    private let report = StoreLoadFailureReport(
        errorDetails: "Error Domain=NSCocoaErrorDomain Code=134110",
        appVersion: "1.0",
        buildNumber: "125"
    )

    @Test
    func textContainsVersionBuildAndErrorDetails() {
        #expect(report.text.contains("1.0"))
        #expect(report.text.contains("(125)"))
        #expect(report.text.contains("Error Domain=NSCocoaErrorDomain Code=134110"))
    }

    @Test
    func mailURLCarriesRecipientSubjectAndBody() throws {
        let url = try #require(report.mailURL(to: "app@example.com", subject: "S"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.scheme == "mailto")
        #expect(components.path == "app@example.com")
        #expect(components.queryItems?.first { $0.name == "subject" }?.value == "S")
        #expect(components.queryItems?.first { $0.name == "body" }?.value == report.text)
    }

    @Test
    func mailURLIsNilWithoutAnAddress() {
        #expect(report.mailURL(to: "", subject: "S") == nil)
    }

    @Test
    func currentReadsVersionAndBuildWithoutEmptyFallbacks() {
        let current = StoreLoadFailureReport.current(errorDetails: "details")

        #expect(!current.appVersion.isEmpty)
        #expect(!current.buildNumber.isEmpty)
        #expect(current.errorDetails == "details")
    }
}
