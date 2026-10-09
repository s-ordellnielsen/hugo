import Foundation

/// One line of a monthly report: the aggregate Field Service line (`id == ""`) or one separate category (`id == category name`).
nonisolated struct ReportingLine: Identifiable, Hashable, Sendable {
    let id: String
    let type: TrackerType
    let name: String
    let iconName: String
    /// All seconds logged on this line in the month, including carried-in entries.
    let actualSeconds: TimeInterval
    /// The part of `actualSeconds` that came from generated carry entries.
    let carriedInSeconds: TimeInterval
    /// Source months of the carried-in seconds, for a "from May" label.
    let carriedInFrom: [YearMonth]

    var remainderSeconds: TimeInterval {
        actualSeconds.truncatingRemainder(dividingBy: 3_600)
    }

    var needsRule: Bool {
        remainderSeconds > 0
    }
}

nonisolated enum RemainderDisposition: Hashable, Sendable {
    case none
    case undecided(seconds: TimeInterval)
    case roundedUp(seconds: TimeInterval)
    case roundedDown(seconds: TimeInterval)
    case transferred(seconds: TimeInterval)
}

nonisolated struct ReportingLineResult: Identifiable, Hashable, Sendable {
    let line: ReportingLine
    let rule: RoundingRule?
    let submittedHours: Int
    let disposition: RemainderDisposition

    var id: String {
        line.id
    }
}

extension ReportingLineResult {
    var persisted: SubmittedReport.SubmittedReportingLine {
        .init(
            typeRaw: line.type.rawValue,
            typeName: line.id,
            durationInSeconds: line.actualSeconds,
            submittedHours: submittedHours,
            roundingRaw: rule?.rawValue ?? ""
        )
    }
}
