import Foundation

struct TheocraticYearMonth: Identifiable {
    let id: YearMonth
    let displayName: String
    let summary: MonthlyReportSummary?
    let isFuture: Bool
}

struct TheocraticYearReport {
    let year: TheocraticYear
    let months: [TheocraticYearMonth]
    let totalSeconds: TimeInterval
    let totalBibleStudies: Int
    let mainDuration: TimeInterval
    let separateDuration: TimeInterval

    var hasEntries: Bool { months.contains { $0.summary != nil } }
}
