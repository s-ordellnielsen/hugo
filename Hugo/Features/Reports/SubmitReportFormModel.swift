import Foundation
import Observation
import SwiftData

/// State and workflow for the monthly report submission sheet. Pure logic
/// (rounding, composing, due checks) lives in the domain enums; this model
/// only coordinates inputs, derived values, and persistence.
@MainActor
@Observable
final class SubmitReportFormModel {
    let month: YearMonth

    var selectedRule: RoundingRule {
        didSet { recompute() }
    }

    /// The composed message ready to hand to Messages (or the pasteboard).
    /// Set by `prepareSubmission()`; cleared when the rule changes.
    private(set) var preparedContent: ReportMessageContent?

    private let calendar: Calendar
    private let now: Date
    private let locale: Locale
    private let userDefaults: UserDefaults

    private var entries: [Entry] = []
    private var submissions: [SubmittedReport] = []

    init(
        month: YearMonth,
        calendar: Calendar = .current,
        now: Date = .now,
        locale: Locale = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.month = month
        self.calendar = calendar
        self.now = now
        self.locale = locale
        self.userDefaults = userDefaults
        let rawDefault = userDefaults.string(forKey: UserDefaultsKeys.defaultRoundingRule)
        self.selectedRule = RoundingRule(rawValue: rawDefault ?? "") ?? .up
    }

    // MARK: - Inputs

    /// Feeds the model its data. The view calls this on appear and whenever
    /// its queries change, keeping the model free of query concerns.
    func load(entries: [Entry], submissions: [SubmittedReport]) {
        self.entries = entries
        self.submissions = submissions
        recompute()
    }

    // MARK: - Derived values

    var summary: MonthlyReportSummary? {
        MonthlyReportBuilder.summaries(from: monthEntries, calendar: calendar).first
    }

    /// The previous month's real submission, if any. Backfill sentinels and
    /// missing submissions both yield zero carry-in.
    var previousSubmission: SubmittedReport? {
        let previousMonth = YearMonth.previous(before: month, calendar: calendar)
        guard
            let submission = submissions.first(where: {
                $0.year == previousMonth.year && $0.month == previousMonth.month
            }), (submission.submittedAt ?? .distantPast) != .distantPast
        else { return nil }
        return submission
    }

    var carriedIn: TimeInterval {
        previousSubmission?.carriedOutSeconds ?? 0
    }

    private(set) var computation: RoundingComputation = RoundingComputation(
        submittedHours: 0,
        categoryHours: [:],
        carriedOutSeconds: 0,
        roundedUpSeconds: 0,
        roundedDownSeconds: 0
    )

    /// An existing report for this exact month (re-submission replaces it).
    var existingSubmission: SubmittedReport? {
        submissions.first { $0.year == month.year && $0.month == month.month }
    }

    /// A report can be submitted for every past or current month, including
    /// a zero-activity month. Persisting that zero-valued snapshot records an
    /// intentional report submission and prevents the reminder from recurring.
    var isSubmittable: Bool {
        month <= now.yearMonth(using: calendar)
    }

    var overseerFullName: String {
        userDefaults.string(forKey: UserDefaultsKeys.overseerFullName) ?? ""
    }

    var overseerPhoneNumber: String {
        userDefaults.string(forKey: UserDefaultsKeys.overseerPhoneNumber) ?? ""
    }

    var hasOverseer: Bool {
        !overseerPhoneNumber.isEmpty
    }

    // MARK: - Workflow

    /// Builds the message for the current rule. The view presents Messages
    /// (or copies to the pasteboard) from the returned content, then calls
    /// `persistSubmission(in:)` once the user confirms.
    @discardableResult
    func prepareSubmission() -> ReportMessageContent? {
        guard isSubmittable else { return nil }

        let summary =
            self.summary
            ?? MonthlyReportSummary(
                id: month,
                displayName: month.monthYearString(calendar: calendar),
                totalSeconds: 0,
                totalBibleStudies: 0,
                mainDuration: 0,
                separateDuration: 0,
                categories: [],
                entries: []
            )

        let content = ReportComposer.message(
            summary: summary,
            computation: computation,
            template: greetingTemplate,
            firstName: overseerFirstName,
            lastName: overseerLastName,
            locale: locale,
            calendar: calendar
        )
        preparedContent = content
        return content
    }

    /// Persists the submission snapshot. An existing row for the same month
    /// (a real submission or a V8→V9 backfill sentinel) is updated in place,
    /// preserving `firstSubmittedAt` and the CloudKit record identity; the
    /// theocratic-year rollup keys submissions by month and would double-count
    /// a delete-and-insert duplicate.
    /// Returns the stored report (nil when not submittable).
    @discardableResult
    func persistSubmission(in context: ModelContext) -> SubmittedReport? {
        guard isSubmittable else { return nil }

        let summary = self.summary
        let snapshots = (summary?.categories ?? []).map { category in
            SubmittedReport.SubmittedCategory(
                name: category.name,
                iconName: category.iconName,
                typeRaw: category.type?.rawValue,
                actualSeconds: category.duration,
                submittedHours: computation.categoryHours[category.id] ?? 0
            )
        }

        if let existing = existingSubmission {
            if existing.firstSubmittedAt == nil || existing.firstSubmittedAt == .distantPast {
                existing.firstSubmittedAt = now
            }
            existing.submittedAt = now
            existing.entriesClosedAt = monthEntries.map(\.createdAt).max() ?? now
            existing.roundingRuleRaw = selectedRule.rawValue
            existing.fieldServiceSeconds = summary?.mainDuration ?? 0
            existing.actualTotalSeconds = (summary?.totalSeconds ?? 0) + carriedIn
            existing.submittedHours = computation.submittedHours
            existing.carriedInSeconds = carriedIn
            existing.carriedOutSeconds = computation.carriedOutSeconds
            existing.roundedUpSeconds = computation.roundedUpSeconds
            existing.roundedDownSeconds = computation.roundedDownSeconds
            existing.totalBibleStudies = summary?.totalBibleStudies ?? 0
            existing.categories = snapshots
            try? context.save()
            return existing
        }

        let report = SubmittedReport(
            year: month.year,
            month: month.month,
            firstSubmittedAt: now,
            submittedAt: now,
            entriesClosedAt: monthEntries.map(\.createdAt).max() ?? now,
            roundingRuleRaw: selectedRule.rawValue,
            fieldServiceSeconds: summary?.mainDuration ?? 0,
            actualTotalSeconds: (summary?.totalSeconds ?? 0) + carriedIn,
            submittedHours: computation.submittedHours,
            carriedInSeconds: carriedIn,
            carriedOutSeconds: computation.carriedOutSeconds,
            roundedUpSeconds: computation.roundedUpSeconds,
            roundedDownSeconds: computation.roundedDownSeconds,
            totalBibleStudies: summary?.totalBibleStudies ?? 0,
            categories: snapshots
        )
        context.insert(report)
        try? context.save()
        return report
    }

    // MARK: - Private

    private var monthEntries: [Entry] {
        entries.filter { $0.date.yearMonth(using: calendar) == month }
    }

    private var greetingTemplate: String {
        let stored = userDefaults.string(forKey: UserDefaultsKeys.overseerGreetingTemplate)

        return stored?.isEmpty == false
            ? stored!
            : String(localized: "report.greeting.default", locale: locale)
    }

    private var overseerFirstName: String {
        // Stored by Task 6's overseer picker; falls back to the full name.
        userDefaults.string(forKey: "overseerFirstName") ?? overseerFullName
    }

    private var overseerLastName: String {
        userDefaults.string(forKey: "overseerLastName") ?? ""
    }

    private func recompute() {
        preparedContent = nil
        computation = ReportRoundingCalculator.compute(
            summary: summary
                ?? MonthlyReportSummary(
                    id: month,
                    displayName: month.monthYearString(calendar: calendar),
                    totalSeconds: 0,
                    totalBibleStudies: 0,
                    mainDuration: 0,
                    separateDuration: 0,
                    categories: [],
                    entries: []
                ),
            carriedIn: carriedIn,
            rule: selectedRule
        )
    }
}
