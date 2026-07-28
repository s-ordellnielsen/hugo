import Foundation

struct TheocraticYearMonth: Identifiable {
    let id: YearMonth
    let displayName: String
    let summary: MonthlyReportSummary?
    let isFuture: Bool
    let submittedReport: SubmittedReport?
    let hasUnreportedEntries: Bool

    /// True only for real submissions — the V8→V9 backfill sentinel
    /// (`submittedAt == .distantPast`) means "never submitted".
    var isSubmitted: Bool {
        guard let submittedReport else { return false }
        return submittedReport.submittedAt != .distantPast
    }
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
