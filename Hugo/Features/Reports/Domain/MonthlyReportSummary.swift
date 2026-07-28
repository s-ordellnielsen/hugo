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
    let mainDuration: TimeInterval
    let separateDuration: TimeInterval
    let categories: [MonthlyCategorySummary]
    let entries: [Entry]
}
