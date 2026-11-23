import Foundation
import Testing

@testable import Hugo

@MainActor
struct SubmittedReportSubmissionTests {
    private let sent = Date(timeIntervalSince1970: 1_000)

    @Test
    func backfilledPlaceholderIsNotSubmitted() {
        // The initializer default, and what the V8 to V9 upgrade stored.
        let report = SubmittedReport(year: 2026, month: 6, entriesClosedAt: sent)

        #expect(report.submittedAt == .distantPast)
        #expect(!report.isSubmitted)
        #expect(report.submittedDate == nil)
        #expect(report.firstSubmittedDate == nil)
    }

    @Test
    func reportWithNilDatesIsNotSubmitted() {
        let report = SubmittedReport(year: 2026, month: 6)
        report.submittedAt = nil
        report.firstSubmittedAt = nil

        #expect(!report.isSubmitted)
        #expect(report.submittedDate == nil)
        #expect(report.firstSubmittedDate == nil)
    }

    @Test
    func genuinelySubmittedReportExposesItsDates() {
        let first = Date(timeIntervalSince1970: 500)
        let report = SubmittedReport(year: 2026, month: 6, firstSubmittedAt: first, submittedAt: sent)

        #expect(report.isSubmitted)
        #expect(report.submittedDate == sent)
        #expect(report.firstSubmittedDate == first)
    }

    @Test
    func missingCutoffCoversNoEntries() {
        let withDefault = SubmittedReport(year: 2026, month: 6)
        let withNil = SubmittedReport(year: 2026, month: 6)
        withNil.entriesClosedAt = nil
        let withDate = SubmittedReport(year: 2026, month: 6, entriesClosedAt: sent)

        #expect(withDefault.entriesCutoff == .distantPast)
        #expect(withNil.entriesCutoff == .distantPast)
        #expect(withDate.entriesCutoff == sent)
    }
}
