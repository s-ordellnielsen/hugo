import Foundation

/// One month together with its entries and its canonical report. Every screen
/// that shows a month reads submitted state, unreported changes and the year
/// contribution from here.
nonisolated struct ServiceMonth: Identifiable {
    /// How a submitted month differs from the report that was sent.
    enum UnreportedChange: Equatable, Sendable {
        /// At least one entry was created after the report was sent. Those
        /// entries answer true to `isUnreported(_:)`.
        case newEntries
        /// No entry is newer than the report, but the month's line totals or
        /// Bible studies no longer match it (an entry was edited or deleted).
        case changedTotals
    }

    let id: YearMonth
    let displayName: String
    let summary: MonthlyReportSummary?
    let isFuture: Bool
    /// The canonical stored report. It can be a placeholder; use `isSubmitted`.
    let submittedReport: SubmittedReport?
    /// Nil when the month was never submitted or still matches its report.
    let unreportedChange: UnreportedChange?

    var isSubmitted: Bool {
        submittedReport.map(SubmittedReportSelection.isReal) ?? false
    }

    /// True when the month was submitted and `entry` was created after the report was sent.
    func isUnreported(_ entry: Entry) -> Bool {
        guard isSubmitted, let submittedReport else { return false }
        return entry.createdAt > (submittedReport.entriesClosedAt ?? .distantPast)
    }

    /// What this month adds to the year total: reported hours when submitted,
    /// logged time otherwise.
    var contribution: MonthContribution {
        if let submission = submittedReport, SubmittedReportSelection.isReal(submission) {
            let studies = submission.totalBibleStudies ?? 0

            guard !submission.reportingLines.isEmpty else {
                let main = TimeInterval(submission.submittedHours ?? 0) * 3_600
                return MonthContribution(total: main, main: main, separate: 0, bibleStudies: studies)
            }

            let main = submission.reportingLines
                .filter { $0.type == .main }
                .reduce(0) { $0 + TimeInterval($1.submittedHours) * 3_600 }
            let separate = submission.reportingLines
                .filter { $0.type == .separate }
                .reduce(0) { $0 + TimeInterval($1.submittedHours) * 3_600 }
            return MonthContribution(total: main + separate, main: main, separate: separate, bibleStudies: studies)
        }

        guard let summary else {
            return MonthContribution(total: 0, main: 0, separate: 0, bibleStudies: 0)
        }

        return MonthContribution(
            total: summary.totalSeconds,
            main: summary.mainDuration,
            separate: summary.separateDuration,
            bibleStudies: summary.totalBibleStudies
        )
    }

    /// What rounding did to the month's submitted report, or nil when the
    /// month isn't submitted, its report has no saved lines, or nothing was
    /// rounded or transferred.
    var adjustments: ReportAdjustments? {
        guard isSubmitted, let report = submittedReport, !report.reportingLines.isEmpty else { return nil }
        let adjustments = ReportAdjustments(lines: report.reportingLines)
        return adjustments.isEmpty ? nil : adjustments
    }

    /// The month's carried-in time, or nil when it has none.
    var carriedIn: CarriedInTime? {
        CarriedInTime(entries: summary?.entries ?? [])
    }

    static func make(
        _ month: YearMonth,
        entries: [Entry],
        submissions: [SubmittedReport],
        trackers: [Tracker] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> ServiceMonth {
        let monthEntries = entries.filter { $0.date.yearMonth(using: calendar) == month }
        let summary = MonthlyReportBuilder.summaries(
            from: monthEntries, calendar: calendar, locale: locale, trackers: trackers
        ).first
        let report = SubmittedReportSelection.canonical(for: month, in: submissions)
        return ServiceMonth(
            id: month,
            displayName: summary?.displayName ?? month.monthYearString(locale: locale, calendar: calendar),
            summary: summary,
            isFuture: month > now.yearMonth(using: calendar),
            submittedReport: report,
            unreportedChange: unreportedChange(report: report, monthEntries: monthEntries, calendar: calendar)
        )
    }

    /// How the month differs from its submitted report, or nil when it was
    /// never submitted (no report, or a V8 to V9 placeholder) or still matches.
    /// `.newEntries` means an entry was created after the submission's
    /// `entriesClosedAt` cutoff. `.changedTotals` means no entry is newer, but
    /// the month's current per-line totals or Bible studies differ from what was
    /// submitted. The comparison applies only to reports whose stored lines add
    /// up to their `actualTotalSeconds`; reports migrated from V10 may not, and
    /// keep the creation-time rule alone.
    private static func unreportedChange(
        report: SubmittedReport?, monthEntries: [Entry], calendar: Calendar
    ) -> UnreportedChange? {
        guard let report, SubmittedReportSelection.isReal(report) else { return nil }
        let cutoff = report.entriesClosedAt ?? .distantPast
        if monthEntries.contains(where: { $0.createdAt > cutoff }) { return .newEntries }
        guard isComparable(report), hasChangedTotals(report: report, monthEntries: monthEntries, calendar: calendar)
        else { return nil }
        return .changedTotals
    }

    private static let toleranceSeconds: TimeInterval = 1

    private static func isComparable(_ report: SubmittedReport) -> Bool {
        guard !report.reportingLines.isEmpty, let actual = report.actualTotalSeconds else { return false }
        let storedTotal = report.reportingLines.reduce(0) { $0 + $1.durationInSeconds }
        return abs(storedTotal - actual) < toleranceSeconds
    }

    private static func hasChangedTotals(report: SubmittedReport, monthEntries: [Entry], calendar: Calendar) -> Bool {
        let bibleStudies = monthEntries.reduce(0) { $0 + $1.bibleStudies }
        if bibleStudies != (report.totalBibleStudies ?? 0) { return true }

        let stored = Dictionary(report.reportingLines.map { ($0.id, $0.durationInSeconds) }, uniquingKeysWith: +)
        let current = Dictionary(
            ReportingLineCalculator.lines(from: monthEntries, calendar: calendar).map { ($0.id, $0.actualSeconds) },
            uniquingKeysWith: +)
        let ids = Set(stored.keys).union(current.keys)
        return ids.contains { abs((stored[$0] ?? 0) - (current[$0] ?? 0)) >= toleranceSeconds }
    }
}

/// What one month adds to the year total.
nonisolated struct MonthContribution: Equatable, Sendable {
    let total: TimeInterval
    let main: TimeInterval
    let separate: TimeInterval
    let bibleStudies: Int
}
