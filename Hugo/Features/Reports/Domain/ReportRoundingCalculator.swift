import Foundation

nonisolated struct RoundingComputation {
    let submittedHours: Int
    /// Whole submitted hours per category, keyed by `MonthlyCategorySummary.id`.
    /// The values always sum to `submittedHours`.
    let categoryHours: [String: Int]
    let carriedOutSeconds: TimeInterval
    let roundedUpSeconds: TimeInterval
    let roundedDownSeconds: TimeInterval
}

nonisolated enum ReportRoundingCalculator {
    /// Rounds the month's actual total (including carried-in minutes) to whole
    /// hours according to the given rule.
    ///
    /// Category redistribution: each category's *actual* seconds are first
    /// floored to whole hours, then the remaining hours are distributed to the
    /// largest remainders (ties broken by category sort order — duration
    /// descending, then name, then id — which `MonthlyReportSummary.categories`
    /// is already sorted by). With the transfer rule the remainder minutes ride
    /// along inside `carriedOutSeconds`, so every category then reports exactly
    /// its floored hours.
    static func compute(
        summary: MonthlyReportSummary,
        carriedIn: TimeInterval,
        rule: RoundingRule
    ) -> RoundingComputation {
        let actualTotal = summary.totalSeconds + carriedIn
        let exactHours = actualTotal / 3_600
        let remainder = actualTotal.truncatingRemainder(dividingBy: 3_600)

        let submittedHours: Int
        var carriedOut: TimeInterval = 0
        var roundedUp: TimeInterval = 0
        var roundedDown: TimeInterval = 0

        switch rule {
        case .up:
            submittedHours = remainder == 0 ? Int(exactHours) : Int(exactHours) + 1
            roundedUp = remainder == 0 ? 0 : 3_600 - remainder
        case .down:
            submittedHours = Int(exactHours)
            roundedDown = remainder
        case .transfer:
            submittedHours = Int(exactHours)
            carriedOut = remainder
        }

        let categoryHours = distributeHours(
            submittedHours: submittedHours,
            categories: summary.categories
        )

        return RoundingComputation(
            submittedHours: submittedHours,
            categoryHours: categoryHours,
            carriedOutSeconds: carriedOut,
            roundedUpSeconds: roundedUp,
            roundedDownSeconds: roundedDown
        )
    }

    private static func distributeHours(
        submittedHours: Int,
        categories: [MonthlyCategorySummary]
    ) -> [String: Int] {
        let hours: [String: Int] = [:]
        guard !categories.isEmpty else { return hours }

        var floors: [String: Int] = [:]
        var assigned = 0
        for category in categories {
            let floor = Int(category.duration / 3_600)
            floors[category.id] = floor
            assigned += floor
        }

        var remaining = submittedHours - assigned

        // Grant one extra hour to the largest remainders first; ties keep the
        // summary's category sort order. Only categories with a leftover
        // remainder qualify, so the distribution always sums to
        // `submittedHours`.
        if remaining > 0 {
            let byLargestRemainder = categories.enumerated().sorted {
                let lhsRemainder = $0.element.duration.truncatingRemainder(dividingBy: 3_600)
                let rhsRemainder = $1.element.duration.truncatingRemainder(dividingBy: 3_600)
                if lhsRemainder != rhsRemainder { return lhsRemainder > rhsRemainder }
                return $0.offset < $1.offset
            }

            for (_, category) in byLargestRemainder where remaining > 0 {
                let remainder = category.duration.truncatingRemainder(dividingBy: 3_600)
                guard remainder > 0 else { continue }
                floors[category.id, default: 0] += 1
                remaining -= 1
            }
        }

        // Whole-hour categories can force the floor sum above the rounded
        // total; trim from the largest remainders last (i.e. smallest
        // remainder first among categories that hold an hour) to restore the
        // invariant.
        if remaining < 0 {
            let bySmallestRemainder = categories.enumerated().sorted {
                let lhsRemainder = $0.element.duration.truncatingRemainder(dividingBy: 3_600)
                let rhsRemainder = $1.element.duration.truncatingRemainder(dividingBy: 3_600)
                if lhsRemainder != rhsRemainder { return lhsRemainder < rhsRemainder }
                return $0.offset > $1.offset
            }

            for (_, category) in bySmallestRemainder where remaining < 0 {
                guard let current = floors[category.id], current > 0 else { continue }
                floors[category.id] = current - 1
                remaining += 1
            }
        }

        return floors
    }
}
