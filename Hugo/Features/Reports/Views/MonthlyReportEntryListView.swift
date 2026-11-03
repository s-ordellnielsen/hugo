import SwiftUI

struct MonthlyReportEntryListView: View {
    let month: ServiceMonth

    var body: some View {
        Section {
            ForEach(month.summary?.entries ?? []) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    Label {
                        HStack {
                            Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .none))
                            Spacer()
                            if month.isUnreported(entry) {
                                Image(systemName: "exclamationmark.triangle.fill")

                                    .font(.caption)
                            }
                            Text(ServiceDurationFormatter.string(from: entry.duration))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: entry.resolvedCategory().iconName)
                    }
                }
            }
        }
    }
}
