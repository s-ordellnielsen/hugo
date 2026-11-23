import Foundation
import Testing

@testable import Hugo

@MainActor
struct SubmittedReportSelectionTests {
    private let sent = Date(timeIntervalSince1970: 1_780_000_000)
    private let june = YearMonth(year: 2026, month: 6)

    @Test
    func aSubmittedReportBeatsOneWithAMissingSubmittedAtEvenWhenTheOtherClosedLater() {
        let missing = SubmittedReport(year: 2026, month: 6, entriesClosedAt: sent.addingTimeInterval(86_400))
        missing.submittedAt = nil
        let submitted = SubmittedReport(year: 2026, month: 6, submittedAt: sent, entriesClosedAt: sent)

        let canonical = SubmittedReportSelection.canonical(for: june, in: [missing, submitted])

        #expect(canonical === submitted)
    }

    @Test
    func aMonthWithOnlyMissingAndPlaceholderReportsHasNoSubmittedOne() throws {
        let missing = SubmittedReport(year: 2026, month: 6)
        missing.submittedAt = nil
        let placeholder = SubmittedReport(year: 2026, month: 6, submittedAt: .distantPast)

        let canonical = try #require(SubmittedReportSelection.canonical(for: june, in: [missing, placeholder]))

        #expect(!canonical.isSubmitted)
    }

    @Test
    func reportsWithAnInvalidYearOrMonthAreNeverIndexed() {
        let noYear = SubmittedReport(year: 2026, month: 6, submittedAt: sent)
        noYear.year = nil
        let noMonth = SubmittedReport(year: 2026, month: 6, submittedAt: sent)
        noMonth.month = nil
        let zeroYear = SubmittedReport(year: 0, month: 6, submittedAt: sent)
        let zeroMonth = SubmittedReport(year: 2026, month: 0, submittedAt: sent)
        let monthThirteen = SubmittedReport(year: 2026, month: 13, submittedAt: sent)

        let byMonth = SubmittedReportSelection.canonicalByMonth([
            noYear, noMonth, zeroYear, zeroMonth, monthThirteen,
        ])

        #expect(byMonth.isEmpty)
    }

    @Test
    func eachMonthKeepsItsOwnCanonicalReport() {
        let juneReport = SubmittedReport(year: 2026, month: 6, submittedAt: sent)
        let julyReport = SubmittedReport(year: 2026, month: 7, submittedAt: sent)

        let byMonth = SubmittedReportSelection.canonicalByMonth([juneReport, julyReport])

        #expect(byMonth.count == 2)
        #expect(byMonth[YearMonth(year: 2026, month: 6)] === juneReport)
        #expect(byMonth[YearMonth(year: 2026, month: 7)] === julyReport)
    }
}
