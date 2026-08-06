import Foundation
import Testing

@testable import Hugo

struct ReportRoundingCalculatorTests {
    private func category(
        _ id: String,
        name: String? = nil,
        type: TrackerType? = .main,
        seconds: TimeInterval
    ) -> MonthlyCategorySummary {
        MonthlyCategorySummary(
            id: id,
            name: name ?? id,
            iconName: "tag.fill",
            type: type,
            duration: seconds
        )
    }

    private func summary(
        categories: [MonthlyCategorySummary],
        bibleStudies: Int = 0
    ) -> MonthlyReportSummary {
        MonthlyReportSummary(
            id: YearMonth(year: 2026, month: 6),
            displayName: "June 2026",
            totalSeconds: categories.reduce(0) { $0 + $1.duration },
            totalBibleStudies: bibleStudies,
            mainDuration: categories.filter { $0.type == .main }.reduce(0) { $0 + $1.duration },
            separateDuration: categories.filter { $0.type == .separate }.reduce(0) { $0 + $1.duration },
            categories: categories,
            entries: []
        )
    }

    @Test
    func roundUpAddsRoundedUpSecondsAndYieldsCeil() {
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: [category("field", seconds: 19_200)]),  // 5h20m
            carriedIn: 0,
            rule: .up
        )

        #expect(result.submittedHours == 6)
        #expect(result.roundedUpSeconds == 2_400)
        #expect(result.roundedDownSeconds == 0)
        #expect(result.carriedOutSeconds == 0)
    }

    @Test
    func roundDownYieldsFloorWithRoundedDownSeconds() {
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: [category("field", seconds: 19_200)]),  // 5h20m
            carriedIn: 0,
            rule: .down
        )

        #expect(result.submittedHours == 5)
        #expect(result.roundedDownSeconds == 1_200)
        #expect(result.roundedUpSeconds == 0)
        #expect(result.carriedOutSeconds == 0)
    }

    @Test
    func transferYieldsFloorAndCarriesOutTheRemainder() {
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: [category("field", seconds: 19_200)]),  // 5h20m
            carriedIn: 0,
            rule: .transfer
        )

        #expect(result.submittedHours == 5)
        #expect(result.carriedOutSeconds == 1_200)
        #expect(result.roundedUpSeconds == 0)
        #expect(result.roundedDownSeconds == 0)
    }

    @Test
    func carriedInMinutesParticipateInTheTotal() {
        // 5h20m actual + 40m carried in = exactly 6h; nothing left to carry.
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: [category("field", seconds: 19_200)]),
            carriedIn: 2_400,
            rule: .transfer
        )

        #expect(result.submittedHours == 6)
        #expect(result.carriedOutSeconds == 0)

        let rounded = ReportRoundingCalculator.compute(
            summary: summary(categories: [category("field", seconds: 19_200)]),
            carriedIn: 2_400,
            rule: .up
        )

        #expect(rounded.submittedHours == 6)
        #expect(rounded.roundedUpSeconds == 0)
        #expect(rounded.roundedDownSeconds == 0)
    }

    @Test
    func categoryHoursRedistributeByLargestRemainderWithSortOrderTieBreak() {
        let categories = [
            category("a", seconds: 8_400),  // 2h20m
            category("b", seconds: 6_000),  // 1h40m
            category("c", seconds: 2_400),  // 0h40m
        ]
        // Total 4h40m → floor 4h: floors sum to 3, the extra hour goes to
        // the largest remainder (b, 40m — tie with c broken by category sort
        // order).
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: categories),
            carriedIn: 0,
            rule: .down
        )

        #expect(result.submittedHours == 4)
        #expect(result.roundedDownSeconds == 2_400)
        #expect(result.categoryHours == ["a": 2, "b": 2, "c": 0])
        #expect(result.categoryHours.values.reduce(0, +) == result.submittedHours)
    }

    @Test
    func roundingUpDistributesTheExtraHourToTheLargestRemainder() {
        let categories = [
            category("a", seconds: 8_400),  // 2h20m
            category("b", seconds: 6_000),  // 1h40m
            category("c", seconds: 2_400),  // 0h40m
        ]
        // Total 4h40m → ceil 5h: floors sum to 3, both extra hours go to the
        // 40m remainders in category sort order (b before c).
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: categories),
            carriedIn: 0,
            rule: .up
        )

        #expect(result.submittedHours == 5)
        #expect(result.roundedUpSeconds == 1_200)
        #expect(result.categoryHours == ["a": 2, "b": 2, "c": 1])
        #expect(result.categoryHours.values.reduce(0, +) == result.submittedHours)
    }

    @Test
    func transferKeepsCategoriesAtTheirFloorWhileRemainderRidesAlong() {
        let categories = [
            category("a", seconds: 8_400),  // 2h20m
            category("b", seconds: 6_000),  // 1h40m
            category("c", seconds: 2_400),  // 0h40m
        ]
        // Total 4h40m → floor 4h: the extra hour goes to the largest
        // remainder (b, 40m — tie with c broken by category sort order); the
        // leftover 40m rides along as carry-out instead of being dropped.
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: categories),
            carriedIn: 0,
            rule: .transfer
        )

        #expect(result.submittedHours == 4)
        #expect(result.carriedOutSeconds == 2_400)
        #expect(result.categoryHours == ["a": 2, "b": 2, "c": 0])
        #expect(result.categoryHours.values.reduce(0, +) == result.submittedHours)
    }

    @Test
    func carriedInMinutesCanCompleteAnExtraHour() {
        let categories = [
            category("a", seconds: 8_400),  // 2h20m
            category("b", seconds: 6_000),  // 1h40m
            category("c", seconds: 2_400),  // 0h40m
        ]
        // Total 4h40m with 40m carried in → 5h20m → floor 5h: both extra
        // hours go to the 40m remainders in category sort order (b before c);
        // the remaining 20m leaves as carry-out.
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: categories),
            carriedIn: 2_400,
            rule: .transfer
        )

        #expect(result.submittedHours == 5)
        #expect(result.carriedOutSeconds == 1_200)
        #expect(result.categoryHours == ["a": 2, "b": 2, "c": 1])
        #expect(result.categoryHours.values.reduce(0, +) == result.submittedHours)
    }

    @Test
    func wholeHourCategoriesAreTrimmedToKeepTheSum() {
        let categories = [
            category("a", seconds: 10_800),  // exactly 3h
            category("b", seconds: 1_800),  // 0h30m
        ]
        // Total 3h30m → floor 3h: floors already sum to 3, b stays 0.
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: categories),
            carriedIn: 0,
            rule: .down
        )

        #expect(result.submittedHours == 3)
        #expect(result.categoryHours == ["a": 3, "b": 0])
        #expect(result.categoryHours.values.reduce(0, +) == result.submittedHours)
    }

    @Test
    func zeroMinuteMonthsNeedNoRounding() {
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: [category("field", seconds: 7_200)]),
            carriedIn: 0,
            rule: .up
        )

        #expect(result.submittedHours == 2)
        #expect(result.roundedUpSeconds == 0)
        #expect(result.roundedDownSeconds == 0)
        #expect(result.carriedOutSeconds == 0)
        #expect(result.categoryHours == ["field": 2])
    }

    @Test
    func emptyMonthWithCarryInReportsTheCarriedHour() {
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: []),
            carriedIn: 3_600,
            rule: .transfer
        )

        #expect(result.submittedHours == 1)
        #expect(result.carriedOutSeconds == 0)
        #expect(result.categoryHours.isEmpty)
    }
}

extension ReportRoundingCalculatorTests {
    @Test
    func distributeHoursWithNoCategoriesReturnsEmpty() {
        let result = ReportRoundingCalculator.compute(
            summary: summary(categories: []),
            carriedIn: 0,
            rule: .transfer
        )

        #expect(result.categoryHours.isEmpty)
    }
}
