import Foundation
import Testing

@testable import Hugo

struct PlannerTargetPreviewTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let locale = Locale(identifier: "en_US_POSIX")
    private let regular = PublisherStatus.status(for: "regular-pioneer")!
    private let auxiliary = PublisherStatus.status(for: "auxiliary-pioneer")!
    private let publisher = PublisherStatus.status(for: "publisher")!

    @Test
    func factualGoalMarkerAndStableScaleDoNotDependOnSelectedBase() {
        let monthly = preview(base: .monthlyGoal, credited: 95 * 3_600)
        let adjusted = preview(base: .yearlyGoalShare, credited: 95 * 3_600)

        #expect(monthly.monthlyBaseSeconds == TimeInterval(50 * 3_600))
        #expect(monthly.solidFraction == monthly.markerFraction)
        #expect(adjusted.adjustedBaseSeconds == TimeInterval(51 * 3_600))
        #expect(adjusted.scaleSeconds == monthly.scaleSeconds)
        #expect(adjusted.markerFraction == monthly.markerFraction)
        #expect(adjusted.solidFraction != monthly.solidFraction)
    }

    @Test
    func bufferOnlyExtendsTheBaseAndFitsTheReservedScale() {
        let zero = preview(base: .monthlyGoal, credited: 95 * 3_600, extra: 0)
        let withinHeadroom = preview(base: .monthlyGoal, credited: 95 * 3_600, extra: 10)
        let maximum = preview(base: .monthlyGoal, credited: 95 * 3_600, extra: 30)

        #expect(zero.extendedFraction == zero.solidFraction)
        #expect(withinHeadroom.scaleSeconds == zero.scaleSeconds)
        #expect(withinHeadroom.solidFraction == zero.solidFraction)
        #expect(withinHeadroom.markerFraction == zero.markerFraction)
        #expect(maximum.extendedFraction! < 1)
        #expect(maximum.extendedFraction! > maximum.solidFraction!)
        #expect(maximum.markerFraction != zero.markerFraction)
        #expect(maximum.totalSeconds == TimeInterval(80 * 3_600))
    }

    @Test
    func metYearlyGoalKeepsMarkerAndShowsOnlyBufferWhenSelected() {
        let noBuffer = preview(base: .yearlyGoalShare, credited: 700 * 3_600)
        let withBuffer = preview(base: .yearlyGoalShare, credited: 700 * 3_600, extra: 5)

        #expect(noBuffer.adjustedBaseSeconds == 0)
        #expect(noBuffer.totalSeconds == nil)
        #expect(noBuffer.solidFraction == 0)
        #expect(noBuffer.markerFraction != nil)
        #expect(withBuffer.totalSeconds == TimeInterval(5 * 3_600))
        #expect(withBuffer.solidFraction == 0)
        #expect(withBuffer.extendedFraction! > 0)
    }

    @Test
    func noGoalDoesNotInventBarAndUsesAdditionsAsTheTarget() {
        let none = preview(base: .monthlyGoal, credited: 0, status: publisher)
        let target = preview(base: .monthlyGoal, credited: 0, status: publisher, extra: 3)
        let nilStatus = preview(base: .monthlyGoal, credited: 0, status: nil)

        #expect(none.goalSeconds == nil)
        #expect(none.solidFraction == nil)
        #expect(none.totalSeconds == nil)
        #expect(target.totalSeconds == TimeInterval(3 * 3_600))
        #expect(target.extendedFraction == nil)
        #expect(nilStatus.totalSeconds == nil)
    }

    @Test
    func auxiliaryUsesMonthlyGoalDespiteStoredYearlyShareAndNegativeBufferIsClamped() {
        let result = preview(base: .yearlyGoalShare, credited: 0, status: auxiliary, extra: -2)

        #expect(result.monthlyBaseSeconds == TimeInterval(30 * 3_600))
        #expect(result.adjustedBaseSeconds == TimeInterval(30 * 3_600))
        #expect(result.bufferSeconds == 0)
    }

    @Test
    func candidateBaseMatchesAuthoritativeTargetCalculator() {
        for credited in [95.0, 110.0, 700.0].map({ $0 * 3_600 }) {
            let value = preview(base: .yearlyGoalShare, credited: credited)
            let expected =
                PlannerTarget.seconds(
                    for: YearMonth(year: 2026, month: 11), base: .yearlyGoalShare, extraHours: 0,
                    status: regular, creditedBeforeCurrentMonth: credited,
                    now: date(2026, 11, 3), calendar: calendar) ?? 0
            #expect(value.adjustedBaseSeconds == expected)
        }
    }

    private func preview(
        base: PlannerTargetBase,
        credited: TimeInterval,
        status: PublisherStatus? = PublisherStatus.status(for: "regular-pioneer"),
        extra: Int = 0
    ) -> PlannerTargetPreview {
        PlannerTargetPreview.make(
            base: base, extraHours: extra, status: status, creditedBeforeCurrentMonth: credited,
            now: date(2026, 11, 3, hour: 12), calendar: calendar, locale: locale)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
