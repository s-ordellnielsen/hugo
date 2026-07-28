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
    private let userDefaults: UserDefaults

    private var entries: [Entry] = []
    private var submissions: [SubmittedReport] = []

    init(
        month: YearMonth,
        calendar: Calendar = .current,
        now: Date = .now,
        userDefaults: UserDefaults = .standard
    ) {
        self.month = month
        self.calendar = calendar
        self.now = now
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
        guard let submission = submissions.first(where: {
            $0.year == previousMonth.year && $0.month == previousMonth.month
        }), submission.submittedAt != .distantPast else { return nil }
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

    var isSubmittable: Bool {
        guard month <= now.yearMonth(using: calendar) else { return false }
        return summary != nil || carriedIn > 0
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

        let summary = self.summary ?? MonthlyReportSummary(
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
            calendar: calendar
        )
        preparedContent = content
        return content
    }

    /// Persists the submission snapshot. Re-submitting the same month
    /// replaces the previous report, preserving `firstSubmittedAt`.
    /// Returns the stored report (nil when not submittable).
    @discardableResult
    func persistSubmission(in context: ModelContext) -> SubmittedReport? {
        guard isSubmittable else { return nil }

        let summary = self.summary
        let previous = existingSubmission

        let report = SubmittedReport(
            year: month.year,
            month: month.month,
            firstSubmittedAt: previous?.firstSubmittedAt ?? now,
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
            categories: (summary?.categories ?? []).map { category in
                SubmittedReport.SubmittedCategory(
                    name: category.name,
                    iconName: category.iconName,
                    typeRaw: category.type?.rawValue,
                    actualSeconds: category.duration,
                    submittedHours: computation.categoryHours[category.id] ?? 0
                )
            }
        )

        if let previous {
            context.delete(previous)
        }
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
        return stored?.isEmpty == false ? stored! : "Hi {first}!"
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
            summary: summary ?? MonthlyReportSummary(
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
