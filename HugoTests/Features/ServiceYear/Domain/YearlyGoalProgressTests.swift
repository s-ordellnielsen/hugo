import Foundation
import Testing

@testable import Hugo

struct YearlyGoalProgressTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US_POSIX")
    private let status = PublisherStatus.status(for: "regular-pioneer")!
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
    private let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")

    @Test
    func onPaceAtTheEndOfOctoberWhenProRated() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 10, 31, hour: 12))
        #expect(progress.expectedSeconds == TimeInterval(100 * 3_600))
        #expect(progress.differenceSeconds == 0)
        #expect(progress.isOnTrack)
        #expect(progress.barFraction == 0)
    }

    @Test
    func proRatedExpectationGrowsWithTheDayOfTheMonth() throws {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 11, 3, hour: 12))
        #expect(progress.expectedSeconds == TimeInterval(105 * 3_600))
        let fraction = try #require(progress.barFraction)
        #expect(abs(fraction - -0.1) < 1e-9)
    }

    @Test(arguments: [
        (2026, 11, 3, 0.1),
        (2026, 11, 1, 1.0 / 30.0),
        (2026, 11, 30, 1.0),
        (2028, 2, 29, 1.0),
        (2027, 2, 1, 1.0 / 28.0),
    ])
    func currentMonthFractionCountsTodayAsAWholeDay(argument: (Int, Int, Int, Double)) {
        let actual = YearlyGoalProgress.currentMonthFraction(
            now: date(argument.0, argument.1, argument.2), calendar: calendar)
        #expect(abs(actual - argument.3) < 1e-9)
    }

    /// The example in the "Your target this month" help article: a regular
    /// pioneer (50 hours a month) on November 15 expects 2 x 50 + 50 x 15/30 = 125 hours.
    @Test
    func midNovemberExpectsOneHundredTwentyFiveHours() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 11, 15, hour: 12))
        #expect(progress.expectedSeconds == TimeInterval(125 * 3_600))
    }

    @Test
    func barFractionClampsAtBothEnds() {
        let ahead = makeProgress(
            entries: [Entry(date: date(2026, 9, 1), duration: 300 * 3_600, tracker: main)],
            now: date(2026, 10, 31, hour: 12))
        #expect(ahead.barFraction == 1)

        let behind = makeProgress(entries: [], now: date(2026, 10, 31, hour: 12))
        #expect(behind.barFraction == -1)
    }

    @Test
    func creditDiffersFromYearTotalWhenSeparateExceedsTheAllowance() {
        let entries = [
            Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: main),
            Entry(date: date(2026, 9, 2), duration: 20 * 3_600, tracker: separate),
        ]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == 55 * 3_600)
        #expect(progress.yearTotalSeconds == 60 * 3_600)
        #expect(progress.showsYearTotal)
    }

    @Test
    func mainOnlyTimeDoesNotShowAYearTotal() {
        let entries = [Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: main)]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == progress.yearTotalSeconds)
        #expect(!progress.showsYearTotal)
    }

    @Test
    func untrackedTimeCountsTowardTheYearlyGoal() {
        let entries = [Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: nil)]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == 40 * 3_600)
        #expect(progress.creditedSeconds == progress.yearTotalSeconds)
        #expect(!progress.showsYearTotal)
    }

    @Test
    func aPastYearExpectsTheFullYearlyGoal() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2028, 1, 15))
        #expect(progress.expectedSeconds == TimeInterval(600 * 3_600))
    }

    @Test
    func aFutureYearHasNoExpectationAndNoBar() {
        let progress = makeProgress(entries: [], now: date(2026, 8, 15))
        #expect(progress.expectedSeconds == nil)
        #expect(progress.barFraction == nil)
    }

    @Test
    func submittedMonthsUseSubmittedHoursNotRawSeconds() {
        let submission = SubmittedReport(
            year: 2026,
            month: 9,
            submittedAt: date(2026, 10, 1),
            reportingLines: [
                .init(typeRaw: TrackerType.main.rawValue, submittedHours: 4),
                .init(typeRaw: TrackerType.separate.rawValue, typeName: "Bethel", submittedHours: 2),
            ]
        )
        let entries = [Entry(date: date(2026, 9, 1), duration: 30 * 3_600, tracker: main)]
        let progress = makeProgress(entries: entries, submissions: [submission], now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == 6 * 3_600)
        #expect(progress.yearTotalSeconds == 6 * 3_600)
    }

    @Test
    func monthsHoldOneRowPerYearMonth() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 10, 15))
        #expect(progress.months.map(\.id) == TheocraticYear(startYear: 2026).months)
        #expect(progress.months.first?.creditedSeconds == TimeInterval(50 * 3_600))
    }

    @Test
    func statusWithoutAYearlyGoalHasNoProgress() {
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear(startYear: 2026),
            entries: [],
            submissions: [],
            now: date(2026, 10, 15),
            calendar: calendar,
            locale: locale
        )
        let progress = YearlyGoalProgress.make(
            report: report,
            status: PublisherStatus.status(for: "auxiliary-pioneer")!,
            now: date(2026, 10, 15),
            calendar: calendar
        )
        #expect(progress == nil)
    }

    @Test
    func monthRowShowsItsTotalOnlyWhenItDiffersFromCredit() throws {
        let entries = [
            Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: main),
            Entry(date: date(2026, 9, 2), duration: 20 * 3_600, tracker: separate),
        ]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        let september = try #require(progress.months.first { $0.id == YearMonth(year: 2026, month: 9) })
        #expect(september.creditedSeconds == 55 * 3_600)
        #expect(september.totalSeconds == 60 * 3_600)
        #expect(september.showsTotal)
        let october = try #require(progress.months.first { $0.id == YearMonth(year: 2026, month: 10) })
        #expect(!october.showsTotal)
    }

    private func septemberAndOctober() -> [Entry] {
        [
            Entry(date: date(2026, 9, 1), duration: 50 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 1), duration: 50 * 3_600, tracker: main),
        ]
    }

    private func makeProgress(
        entries: [Entry],
        submissions: [SubmittedReport] = [],
        now: Date
    ) -> YearlyGoalProgress {
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear(startYear: 2026),
            entries: entries,
            submissions: submissions,
            now: now,
            calendar: calendar,
            locale: locale
        )
        return YearlyGoalProgress.make(
            report: report,
            status: status,
            now: now,
            calendar: calendar
        )!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
