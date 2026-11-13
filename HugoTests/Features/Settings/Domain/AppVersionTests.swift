import Testing

@testable import Hugo

struct AppVersionTests {
    @Test
    func readsMarketingVersionAndBuildNumber() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "125",
        ])

        #expect(version.displayString == "1.0 (125)")
    }

    @Test
    func missingKeysShowQuestionMarks() {
        #expect(AppVersion(infoDictionary: [:]).displayString == "? (?)")
    }
}
