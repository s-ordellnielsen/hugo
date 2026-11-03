import Foundation
import Testing

@testable import Hugo

@MainActor
struct ServiceMonthTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute
            )
        )!
    }

    private let june = YearMonth(year: 2026, month: 6)

    private func month(_ entries: [Entry], _ submissions: [SubmittedReport]) -> ServiceMonth {
        ServiceMonth.make(june, entries: entries, submissions: submissions, now: date(2026, 7, 15), calendar: calendar)
    }

    @Test
    func unreportedWhenNoReportExists() {
        let m = month([], [])
        #expect(!m.isSubmitted)
        #expect(m.unreportedChange == nil)
    }

    @Test
    func unreportedForSentinelReports() {
        let sentinel = SubmittedReport(
            year: 2026,
            month: 6,
            entriesClosedAt: date(2026, 6, 30)
        )

        let m = month([], [sentinel])
        #expect(!m.isSubmitted)
        #expect(m.unreportedChange == nil)
    }

    @Test
    func entriesCreatedAfterTheCutoffAreUnreported() {
        let report = SubmittedReport(
            year: 2026,
            month: 6,
            firstSubmittedAt: date(2026, 7, 1),
            submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 20, hour: 10)
        )

        let older = Entry(date: date(2026, 6, 10), duration: 3_600, tracker: nil)
        older.createdAt = date(2026, 6, 10, hour: 9)
        let newer = Entry(date: date(2026, 6, 25), duration: 3_600, tracker: nil)
        newer.createdAt = date(2026, 7, 2, hour: 9)

        #expect(month([older], [report]).unreportedChange == nil)

        let m = month([older, newer], [report])
        #expect(m.unreportedChange == .newEntries)
        #expect(m.isUnreported(newer))
        #expect(!m.isUnreported(older))
    }

    @Test
    func entriesFromOtherMonthsDoNotTriggerTheWarning() {
        let report = SubmittedReport(
            year: 2026,
            month: 6,
            firstSubmittedAt: date(2026, 7, 1),
            submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 20, hour: 10)
        )

        let julyEntry = Entry(date: date(2026, 7, 5), duration: 3_600, tracker: nil)
        julyEntry.createdAt = date(2026, 7, 5, hour: 9)

        #expect(month([julyEntry], [report]).unreportedChange == nil)
    }

    // MARK: - Changed totals after submission

    private func comparableReport(mainSeconds: TimeInterval, bibleStudies: Int = 0) -> SubmittedReport {
        SubmittedReport(
            year: 2026, month: 6,
            firstSubmittedAt: date(2026, 7, 1), submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 30, hour: 10),
            actualTotalSeconds: mainSeconds,
            totalBibleStudies: bibleStudies,
            reportingLines: [
                .init(
                    typeRaw: TrackerType.main.rawValue, typeName: "", durationInSeconds: mainSeconds,
                    submittedHours: Int(mainSeconds / 3_600))
            ]
        )
    }

    private func oldEntry(seconds: TimeInterval, bibleStudies: Int? = nil, tracker: Tracker? = nil) -> Entry {
        let entry = Entry(date: date(2026, 6, 10), duration: seconds, tracker: tracker, bibleStudies: bibleStudies)
        entry.createdAt = date(2026, 6, 10, hour: 9)
        return entry
    }

    private func flagged(_ report: SubmittedReport, _ entries: [Entry]) -> ServiceMonth.UnreportedChange? {
        month(entries, [report]).unreportedChange
    }

    @Test
    func unchangedComparableMonthIsNotFlagged() {
        #expect(flagged(comparableReport(mainSeconds: 3_600), [oldEntry(seconds: 3_600)]) == nil)
    }

    @Test
    func editedDurationIsFlagged() {
        #expect(flagged(comparableReport(mainSeconds: 3_600), [oldEntry(seconds: 5_400)]) == .changedTotals)
    }

    @Test
    func deletedEntryIsFlagged() {
        #expect(flagged(comparableReport(mainSeconds: 3_600), []) == .changedTotals)
    }

    @Test
    func newSeparateLineIsFlagged() {
        let bethel = Tracker(name: "Bethel", type: .separate)
        let entries = [oldEntry(seconds: 3_600), oldEntry(seconds: 1_800, tracker: bethel)]
        #expect(flagged(comparableReport(mainSeconds: 3_600), entries) == .changedTotals)
    }

    @Test
    func changedBibleStudiesIsFlagged() {
        let report = comparableReport(mainSeconds: 3_600, bibleStudies: 1)
        #expect(flagged(report, [oldEntry(seconds: 3_600, bibleStudies: 2)]) == .changedTotals)
    }

    @Test
    func lateSyncedEntryIsFlagged() {
        let entries = [oldEntry(seconds: 3_600), oldEntry(seconds: 1_800)]
        #expect(flagged(comparableReport(mainSeconds: 3_600), entries) == .changedTotals)
    }

    @Test
    func nonComparableReportKeepsTheCreatedAtRule() {
        let report = SubmittedReport(
            year: 2026, month: 6,
            firstSubmittedAt: date(2026, 7, 1), submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 30, hour: 10),
            actualTotalSeconds: 5_400,
            reportingLines: [
                .init(typeRaw: TrackerType.main.rawValue, typeName: "", durationInSeconds: 3_600, submittedHours: 1)
            ]
        )
        let edited = oldEntry(seconds: 5_400)
        #expect(flagged(report, [edited]) == nil)

        let newer = Entry(date: date(2026, 6, 25), duration: 600, tracker: nil)
        newer.createdAt = date(2026, 7, 2, hour: 9)
        #expect(flagged(report, [edited, newer]) == .newEntries)
    }

    @Test
    func editedDurationMarksTheMonthButNoEntry() {
        let entries = [oldEntry(seconds: 5_400)]
        let m = month(entries, [comparableReport(mainSeconds: 3_600)])
        #expect(m.unreportedChange == .changedTotals)
        #expect(entries.allSatisfy { !m.isUnreported($0) })
    }

    @Test
    func placeholderReportIsNotSubmitted() {
        let placeholder = SubmittedReport(year: 2026, month: 6, entriesClosedAt: date(2026, 6, 30))
        let entry = Entry(date: date(2026, 6, 10), duration: 3_600, tracker: nil)
        entry.createdAt = date(2026, 7, 2, hour: 9)

        let m = month([entry], [placeholder])
        #expect(!m.isSubmitted)
        #expect(m.unreportedChange == nil)
        #expect(!m.isUnreported(entry))
    }

    @Test
    func submittedMonthContributesReportedHours() {
        let report = SubmittedReport(
            year: 2026, month: 6,
            firstSubmittedAt: date(2026, 7, 1), submittedAt: date(2026, 7, 1),
            entriesClosedAt: date(2026, 6, 30, hour: 10),
            reportingLines: [
                .init(typeRaw: TrackerType.main.rawValue, typeName: "", durationInSeconds: 5_400, submittedHours: 2)
            ]
        )
        let m = month([oldEntry(seconds: 5_400)], [report])
        #expect(m.contribution.total == 7_200)
        #expect(m.contribution.main == 7_200)
    }

    @Test
    func unsubmittedMonthContributesLoggedTime() {
        let m = month([oldEntry(seconds: 5_400)], [])
        #expect(m.contribution.total == 5_400)
    }
}
