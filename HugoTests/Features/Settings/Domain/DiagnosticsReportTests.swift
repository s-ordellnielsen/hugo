import Testing

@testable import Hugo

struct DiagnosticsReportTests {
    private var version: AppVersion {
        AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "125",
        ])
    }

    @Test
    func fullReportTextListsEachFactOnItsOwnLine() {
        let report = DiagnosticsReport(
            appVersion: version,
            systemVersion: "iOS 26.1",
            deviceModel: "iPhone",
            language: "da",
            iCloudStatus: "available",
            schemaName: "SchemaV13",
            schemaVersion: "10.0.0",
            entryCount: 412,
            categoryCount: 5
        )

        #expect(
            report.text
                == [
                    "Hugo 1.0 (125)",
                    "iOS 26.1, iPhone",
                    "Language: da",
                    "iCloud: available",
                    "Schema: SchemaV13 (10.0.0)",
                    "Entries: 412",
                    "Categories: 5",
                ].joined(separator: "\n"))
    }

    @Test
    func missingCountsPrintUnknown() {
        let report = DiagnosticsReport(
            appVersion: version,
            systemVersion: "iOS 26.1",
            deviceModel: "iPad",
            language: "en",
            iCloudStatus: "no account",
            schemaName: "SchemaV13",
            schemaVersion: "10.0.0",
            entryCount: nil,
            categoryCount: nil
        )

        #expect(report.text.contains("Entries: unknown"))
        #expect(report.text.contains("Categories: unknown"))
    }
}
