import Foundation
import Testing

@testable import Hugo

struct PlannerTargetTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US_POSIX")
    private let regular = PublisherStatus.status(for: "regular-pioneer")!
    private let auxiliary = PublisherStatus.status(for: "auxiliary-pioneer")!
    private let publisher = PublisherStatus.status(for: "publisher")!
    private let main = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
    private let separate = Tracker(name: "LDC", type: .separate, iconName: "hammer")

    @Test
    func monthlyGoalIsTheBaseWithoutExtraHours() {
        #expect(target(november, base: .monthlyGoal, status: regular) == TimeInterval(50 * 3_600))
    }

    @Test
    func extraHoursAreAddedToTheMonthlyGoal() {
        #expect(target(november, base: .monthlyGoal, extra: 5, status: regular) == TimeInterval(55 * 3_600))
    }

    @Test
    func yearlyShareIsExactWhenItDividesEvenly() {
        #expect(target(november, status: regular, credited: 100 * 3_600) == TimeInterval(50 * 3_600))
    }

    @Test
    func yearlyShareRoundsUpToWholeHours() {
        #expect(target(november, status: regular, credited: 95 * 3_600) == TimeInterval(51 * 3_600))
        #expect(target(november, status: regular, credited: 90 * 3_600) == TimeInterval(51 * 3_600))
        #expect(target(november, status: regular, credited: 110 * 3_600) == TimeInterval(49 * 3_600))
    }

    @Test
    func yearlyShareIsNilWhenTheGoalIsAlreadyMetAndExtraHoursStillShow() {
        #expect(target(november, status: regular, credited: 700 * 3_600) == nil)
        #expect(target(november, extra: 3, status: regular, credited: 700 * 3_600) == TimeInterval(3 * 3_600))
    }

    @Test
    func decemberUsesTheSameShareAsNovember() {
        #expect(target(december, status: regular, credited: 95 * 3_600) == TimeInterval(51 * 3_600))
    }

    @Test
    func aLaterTheocraticYearUsesTheMonthlyGoal() {
        #expect(
            target(YearMonth(year: 2027, month: 9), status: regular, credited: 95 * 3_600) == TimeInterval(50 * 3_600))
    }

    @Test
    func lastMonthOfTheYearUsesWhatIsLeft() {
        let lastMonth = target(
            YearMonth(year: 2027, month: 8), status: regular, credited: 560 * 3_600,
            now: date(2027, 8, 15, hour: 12))
        #expect(lastMonth == TimeInterval(40 * 3_600))
    }

    @Test
    func statusWithoutYearlyGoalFallsBackToTheMonthlyGoal() {
        #expect(target(november, status: auxiliary) == TimeInterval(30 * 3_600))
    }

    @Test
    func publisherHasNoGoalUnlessExtraHoursAreSet() {
        #expect(target(november, base: .monthlyGoal, status: publisher) == nil)
        #expect(target(november, base: .monthlyGoal, extra: 10, status: publisher) == TimeInterval(10 * 3_600))
        #expect(target(november, base: .monthlyGoal, status: nil) == nil)
    }

    @Test
    func settingSummaryUsesTheSelectedBaseAndPositiveExtra() {
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 5, status: regular, locale: locale)
                == "Monthly goal + 5 hours")
        #expect(
            PlannerTarget.settingSummary(base: .yearlyGoalShare, extraHours: 0, status: regular, locale: locale)
                == "Share of what's left of the yearly goal")
    }

    @Test
    func settingSummaryUsesMonthlyGoalWhenYearlyShareIsUnavailable() {
        #expect(
            PlannerTarget.settingSummary(base: .yearlyGoalShare, extraHours: 0, status: auxiliary, locale: locale)
                == "Monthly goal")
    }

    @Test
    func settingSummaryClampsNegativeExtraAndHandlesStatusesWithoutGoals() {
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: -5, status: regular, locale: locale)
                == "Monthly goal")
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 0, status: publisher, locale: locale)
                == "Not set")
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 0, status: nil, locale: locale) == "Not set")
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 3, status: publisher, locale: locale)
                == "3 hours")
        #expect(
            PlannerTarget.settingSummary(base: .monthlyGoal, extraHours: 3, status: nil, locale: locale) == "3 hours")
    }

    @Test
    func creditedBeforeMonthUsesTheYearlyGoalCreditRule() throws {
        let entries = [
            Entry(date: date(2026, 9, 10, hour: 10), duration: 40 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 10, hour: 10), duration: 30 * 3_600, tracker: main),
            Entry(date: date(2026, 10, 11, hour: 10), duration: 30 * 3_600, tracker: separate),
            Entry(date: date(2026, 11, 2, hour: 10), duration: 10 * 3_600, tracker: main),
        ]
        let report = TheocraticYearReportBuilder.report(
            for: TheocraticYear(startYear: 2026),
            entries: entries,
            now: date(2026, 11, 3, hour: 12),
            calendar: calendar,
            locale: locale)
        let rule = try #require(regular.yearlyGoalRule)

        let credited = PlannerTarget.creditedSeconds(before: november, in: report, rule: rule)

        #expect(credited == TimeInterval(95 * 3_600))
    }

    private var november: YearMonth { YearMonth(year: 2026, month: 11) }
    private var december: YearMonth { YearMonth(year: 2026, month: 12) }

    private func target(
        _ month: YearMonth,
        base: PlannerTargetBase = .yearlyGoalShare,
        extra: Int = 0,
        status: PublisherStatus?,
        credited: TimeInterval = 0,
        now: Date? = nil
    ) -> TimeInterval? {
        PlannerTarget.seconds(
            for: month, base: base, extraHours: extra, status: status,
            creditedBeforeCurrentMonth: credited, now: now ?? date(2026, 11, 3, hour: 12),
            calendar: calendar)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
