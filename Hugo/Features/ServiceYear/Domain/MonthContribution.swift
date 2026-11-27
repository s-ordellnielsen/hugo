import Foundation

/// What one month adds to the year total.
nonisolated struct MonthContribution: Equatable, Sendable {
    let total: TimeInterval
    let main: TimeInterval
    let separate: TimeInterval
    let bibleStudies: Int
    /// School credit in seconds. Counts toward the yearly goal like main time
    /// and is part of `total`.
    var schoolCredit: TimeInterval = 0
}
