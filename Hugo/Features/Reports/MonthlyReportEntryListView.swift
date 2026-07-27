import SwiftUI

struct MonthlyReportEntryListView: View {
    let summary: MonthlyReportSummary

    var body: some View {
        Section {
            ForEach(summary.entries) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    Label {
                        HStack {
                            Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .none))
                            Spacer()
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
