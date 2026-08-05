import Foundation
import Testing

@testable import Hugo

@MainActor
struct TheocraticYearReportBuilderTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test
    func emptyEntriesProduceTwelveEmptyMonthsAndZeroTotals() {
        let report = makeReport(entries: [])
        #expect(report.months.count == 12)
        #expect(!report.hasEntries)
        #expect(report.totalSeconds == 0)
        #expect(report.totalBibleStudies == 0)
        #expect(report.mainDuration == 0)
        #expect(report.separateDuration == 0)
    }

    @Test
    func excludesEntriesOutsideRequestedYear() {
        let report = makeReport(entries: [Entry(date: date(2026, 8, 31), duration: 3_600, tracker: nil)])
        #expect(!report.hasEntries)
        #expect(report.totalSeconds == 0)
    }

    @Test
    func addsSummaryOnlyForMonthsWithEntries() throws {
        let report = makeReport(entries: [Entry(date: date(2026, 9, 1), duration: 3_600, tracker: nil)])
        let september = try #require(report.months.first)
        #expect(september.summary?.totalSeconds == 3_600)
        #expect(report.months.dropFirst().allSatisfy { $0.summary == nil })
    }

    @Test
    func aggregatesTotalsAcrossMonthsAndCategoryTypes() {
        let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let report = makeReport(entries: [
            Entry(date: date(2026, 9, 1), duration: 3_600, tracker: main, bibleStudies: 1),
            Entry(date: date(2027, 1, 1), duration: 1_800, tracker: separate, bibleStudies: 2),
        ])
        #expect(report.totalSeconds == 5_400)
        #expect(report.totalBibleStudies == 3)
        #expect(report.mainDuration == 3_600)
        #expect(report.separateDuration == 1_800)
    }

    @Test
    func ordersMonthsFromSeptemberThroughAugust() {
        let year = TheocraticYear(startYear: 2026)
        let report = makeReport(for: year, entries: [])
        #expect(report.months.map(\.id) == year.months)
    }

    @Test
    func marksOnlyMonthsAfterNowAsFuture() {
        let report = makeReport(entries: [], now: date(2026, 10, 15))
        #expect(report.months[0].isFuture == false)
        #expect(report.months[1].isFuture == false)
        #expect(report.months[2].isFuture == true)
    }

    @Test
    func monthsWithoutSubmissionsAreNotSubmitted() throws {
        let report = makeReport(entries: [Entry(date: date(2026, 9, 1), duration: 3_600, tracker: nil)])
        let september = try #require(report.months.first)

        #expect(september.submittedReport == nil)
        #expect(!september.isSubmitted)
        // No report exists, so the month is per definition unreported.
        #expect(september.hasUnreportedEntries)
    }

    @Test
    func sentinelSubmissionsAreNotTreatedAsSubmitted() throws {
        let sentinel = SubmittedReport(
            year: 2026,
            month: 9,
            entriesClosedAt: date(2026, 9, 30)
        )
        let report = makeReport(
            entries: [Entry(date: date(2026, 9, 1), duration: 3_600, tracker: nil)],
            submissions: [sentinel]
        )
        let september = try #require(report.months.first)

        #expect(september.submittedReport != nil)
        #expect(!september.isSubmitted)
        // The backfill sentinel must never surface "added after submission"
        // warnings for pre-existing entries.
        #expect(september.hasUnreportedEntries)
    }

    @Test
    func realSubmissionMarksTheMonthAsSubmittedWithoutWarnings() throws {
        let entry = Entry(date: date(2026, 9, 1), duration: 3_600, tracker: nil)
        entry.createdAt = date(2026, 9, 1)
        let submission = SubmittedReport(
            year: 2026,
            month: 9,
            firstSubmittedAt: date(2026, 10, 1),
            submittedAt: date(2026, 10, 1),
            entriesClosedAt: date(2026, 9, 30)
        )
        let report = makeReport(entries: [entry], submissions: [submission])
        let september = try #require(report.months.first)

        #expect(september.isSubmitted)
        #expect(!september.hasUnreportedEntries)
    }

    @Test
    func entriesCreatedAfterSubmissionTriggerTheWarning() throws {
        let entry = Entry(date: date(2026, 9, 5), duration: 3_600, tracker: nil)
        entry.createdAt = date(2026, 10, 2)
        let submission = SubmittedReport(
            year: 2026,
            month: 9,
            firstSubmittedAt: date(2026, 10, 1),
            submittedAt: date(2026, 10, 1),
            entriesClosedAt: date(2026, 10, 1)
        )
        let report = makeReport(entries: [entry], submissions: [submission])
        let september = try #require(report.months.first)

        #expect(september.isSubmitted)
        #expect(september.hasUnreportedEntries)
    }

    @Test
    func submissionsAttachToTheirMatchingMonthOnly() throws {
        let submission = SubmittedReport(
            year: 2027,
            month: 1,
            firstSubmittedAt: date(2027, 2, 1),
            submittedAt: date(2027, 2, 1)
        )
        let report = makeReport(entries: [], submissions: [submission])

        #expect(report.months.first { $0.id == YearMonth(year: 2027, month: 1) }?.isSubmitted == true)
        #expect(report.months.filter { $0.isSubmitted }.count == 1)
    }

    @Test
    func duplicateSubmissionsDoNotCrashAndLatestRealSubmissionWins() throws {
        let sentinel = SubmittedReport(
            year: 2026,
            month: 9,
            entriesClosedAt: date(2026, 9, 30)
        )

        let olderSubmission = SubmittedReport(
            year: 2026,
            month: 9,
            firstSubmittedAt: date(2026, 10, 1),
            submittedAt: date(2026, 10, 1),
            entriesClosedAt: date(2026, 9, 30)
        )

        let latestSubmission = SubmittedReport(
            year: 2026,
            month: 9,
            firstSubmittedAt: date(2026, 10, 1),
            submittedAt: date(2026, 10, 3),
            entriesClosedAt: date(2026, 10, 2)
        )

        let report = makeReport(
            entries: [],
            submissions: [
                sentinel,
                olderSubmission,
                latestSubmission,
            ]
        )

        let september = try #require(report.months.first)

        #expect(september.submittedReport === latestSubmission)
        #expect(september.isSubmitted)
    }

    @Test
    func duplicateSentinelsPreferTheOneWithLatestEntriesClosedAt() throws {
        let olderSentinel = SubmittedReport(
            year: 2026,
            month: 9,
            entriesClosedAt: date(2026, 9, 20)
        )

        let latestSentinel = SubmittedReport(
            year: 2026,
            month: 9,
            entriesClosedAt: date(2026, 9, 30)
        )

        let report = makeReport(
            entries: [],
            submissions: [
                olderSentinel,
                latestSentinel,
            ]
        )

        let september = try #require(report.months.first)

        #expect(september.submittedReport === latestSentinel)
        #expect(!september.isSubmitted)
    }

    @Test
    func invalidOptionalSubmissionIsIgnored() throws {
        let invalidSubmission = SubmittedReport(
            year: 2026,
            month: 9
        )

        invalidSubmission.year = nil

        let report = makeReport(
            entries: [],
            submissions: [invalidSubmission]
        )

        let september = try #require(report.months.first)

        #expect(september.submittedReport == nil)
    }

    private func makeReport(entries: [Entry]) -> TheocraticYearReport {
        makeReport(for: TheocraticYear(startYear: 2026), entries: entries, now: date(2026, 10, 15))
    }

    private func makeReport(entries: [Entry], submissions: [SubmittedReport]) -> TheocraticYearReport {
        TheocraticYearReportBuilder.report(
            for: TheocraticYear(startYear: 2026),
            entries: entries,
            submissions: submissions,
            now: date(2026, 10, 15),
            calendar: calendar,
            locale: locale
        )
    }

    private func makeReport(entries: [Entry], now: Date) -> TheocraticYearReport {
        makeReport(for: TheocraticYear(startYear: 2026), entries: entries, now: now)
    }

    private func makeReport(for year: TheocraticYear, entries: [Entry]) -> TheocraticYearReport {
        makeReport(for: year, entries: entries, now: date(2026, 10, 15))
    }

    private func makeReport(for year: TheocraticYear, entries: [Entry], now: Date) -> TheocraticYearReport {
        TheocraticYearReportBuilder.report(
            for: year,
            entries: entries,
            now: now,
            calendar: calendar,
            locale: locale
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
