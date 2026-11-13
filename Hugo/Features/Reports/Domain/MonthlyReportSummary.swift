import Foundation

nonisolated struct MonthlyCategorySummary: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let type: TrackerType?
    let duration: TimeInterval
}

nonisolated struct MonthlyReportSummary: Identifiable {
    let id: YearMonth
    let displayName: String
    let totalSeconds: TimeInterval
    let totalBibleStudies: Int
    /// Logged time in main categories, including untracked time.
    let mainDuration: TimeInterval
    /// Logged time in separate categories.
    let separateDuration: TimeInterval
    let categories: [MonthlyCategorySummary]
    let entries: [Entry]
}
