import Foundation

/// What rounding did to a submitted report, summed over its saved reporting
/// lines: minutes added by rounding up, minutes dropped by rounding down and
/// minutes moved to the next month by a transfer. Read from the report's
/// snapshot only, so it stays correct after categories are renamed or deleted.
nonisolated struct ReportAdjustments: Equatable, Sendable {
    var roundedUpSeconds: TimeInterval = 0
    var roundedDownSeconds: TimeInterval = 0
    var transferredSeconds: TimeInterval = 0

    /// Differences under one second are ignored (floating-point noise).
    private static let toleranceSeconds: TimeInterval = 1

    init(lines: [SubmittedReport.SubmittedReportingLine]) {
        for line in lines {
            let difference = TimeInterval(line.submittedHours) * 3_600 - line.durationInSeconds
            switch line.rounding {
            case .up where difference >= Self.toleranceSeconds:
                roundedUpSeconds += difference
            case .down where -difference >= Self.toleranceSeconds:
                roundedDownSeconds += -difference
            case .transfer where -difference >= Self.toleranceSeconds:
                transferredSeconds += -difference
            default:
                break
            }
        }
    }

    var isEmpty: Bool {
        roundedUpSeconds == 0 && roundedDownSeconds == 0 && transferredSeconds == 0
    }
}
