import SwiftUI

struct MonthlyReportEntryListView: View {
    let summary: MonthlyReportSummary
    /// The month's submission, if any. Entries created after the submission's
    /// `entriesClosedAt` cutoff are marked as not included in the report.
    var report: SubmittedReport? = nil

    private func isUnreported(_ entry: Entry) -> Bool {
        guard let report, (report.submittedAt ?? .distantPast) != .distantPast else { return false }
        return entry.createdAt > (report.entriesClosedAt ?? .distantPast)
    }

    var body: some View {
        Section {
            ForEach(summary.entries) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    Label {
                        HStack {
                            Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .none))
                            Spacer()
                            if isUnreported(entry) {
                                Image(systemName: "exclamationmark.triangle.fill")

                                    .font(.caption)
                            }
                            Text(ServiceDurationFormatter.string(from: entry.duration))
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: entry.tracker?.iconName ?? entry.storedTracker?.icon ?? "questionmark")
                    }
                }
            }
        }
    }
}
