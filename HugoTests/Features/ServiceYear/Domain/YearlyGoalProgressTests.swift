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
    private let rule = YearlyGoalRule(monthlyGoalSeconds: 50 * 3_600, separateAllowanceSeconds: 5 * 3_600)
    private let yearlyGoalSeconds: TimeInterval = 600 * 3_600
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

    @Test
    func completedMonthsPacingIgnoresTheCurrentMonth() {
        let progress = makeProgress(
            entries: septemberAndOctober(), pacing: .completedMonths, now: date(2026, 11, 3, hour: 12))
        #expect(progress.expectedSeconds == TimeInterval(100 * 3_600))
    }

    @Test
    func includeCurrentMonthPacingExpectsTheWholeMonth() {
        let progress = makeProgress(
            entries: septemberAndOctober(), pacing: .includeCurrentMonth, now: date(2026, 11, 3, hour: 12))
        #expect(progress.expectedSeconds == TimeInterval(150 * 3_600))
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
    func creditDiffersFromActualWhenSeparateExceedsTheAllowance() {
        let entries = [
            Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: main),
            Entry(date: date(2026, 9, 2), duration: 20 * 3_600, tracker: separate),
        ]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == 55 * 3_600)
        #expect(progress.actualSeconds == 60 * 3_600)
        #expect(progress.showsActualTotal)
    }

    @Test
    func mainOnlyTimeDoesNotShowAnActualTotal() {
        let entries = [Entry(date: date(2026, 9, 1), duration: 40 * 3_600, tracker: main)]
        let progress = makeProgress(entries: entries, now: date(2026, 10, 15))
        #expect(progress.creditedSeconds == progress.actualSeconds)
        #expect(!progress.showsActualTotal)
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
        #expect(progress.actualSeconds == 6 * 3_600)
    }

    @Test
    func creditedByMonthHoldsOneEntryPerYearMonth() {
        let progress = makeProgress(entries: septemberAndOctober(), now: date(2026, 10, 15))
        let year = TheocraticYear(startYear: 2026)
        #expect(Set(progress.creditedByMonth.keys) == Set(year.months))
        #expect(progress.creditedByMonth[YearMonth(year: 2026, month: 9)] == TimeInterval(50 * 3_600))
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
        pacing: YearlyGoalPacing = .proRated,
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
            rule: rule,
            yearlyGoalSeconds: yearlyGoalSeconds,
            pacing: pacing,
            now: now,
            calendar: calendar
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
