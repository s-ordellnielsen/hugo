import Foundation

/// The one place that knows a placeholder report can store its submission
/// dates as `nil` or as `Date.distantPast`. Older data, and the initializer
/// default of every schema version, use `.distantPast`; `SyncDeduplicator`
/// rewrites stored values to `nil`, but a device on an older build can still
/// sync an unrewritten one in. Read the dates through these properties and
/// never compare a stored date with `.distantPast` anywhere else.
extension SubmittedReport {
    /// When the report was last sent, or nil for a placeholder report.
    var submittedDate: Date? {
        Self.sent(submittedAt)
    }

    /// When the month was first sent, or nil for a placeholder report.
    var firstSubmittedDate: Date? {
        Self.sent(firstSubmittedAt)
    }

    /// False for a placeholder report: a saved report for a month that was
    /// never sent, which the V8 to V9 upgrade created.
    var isSubmitted: Bool {
        submittedDate != nil
    }

    /// Entries created after this moment are unreported. This is a comparison
    /// floor, not a submission marker: a report with no recorded cutoff covers
    /// no entries, so every entry is newer than `.distantPast`.
    var entriesCutoff: Date {
        entriesClosedAt ?? .distantPast
    }

    private static func sent(_ date: Date?) -> Date? {
        guard let date, date != .distantPast else { return nil }
        return date
    }
}
