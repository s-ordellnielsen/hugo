import SwiftUI

/// Submission status block shown on a month row. Renders nothing for months
/// that have never been submitted (including V8→V9 backfill sentinels).
struct MonthSubmissionStatusView: View {
    let month: TheocraticYearMonth

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        if month.isSubmitted, let submittedAt = month.submittedReport?.submittedAt {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "report.status.submitted.\(Self.dateFormatter.string(from: submittedAt))",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                if month.hasUnreportedEntries {
                    Label(
                        "report.status.unreported-entries",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .padding(.top, 8)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MonthSubmissionStatusView(month: ReportPreviewFixtures.submittedMonth)
        MonthSubmissionStatusView(month: ReportPreviewFixtures.submittedMonthWithUnreportedEntries)
        MonthSubmissionStatusView(month: ReportPreviewFixtures.emptyMonth)
    }
    .padding()
}
