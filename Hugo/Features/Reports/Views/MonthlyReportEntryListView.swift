import SwiftUI

struct MonthlyReportEntryListView: View {
    let month: ServiceMonth

    private var entries: [Entry] { month.summary?.entries ?? [] }

    var body: some View {
        Section {
            if let carriedIn = CarriedInTime(entries: entries) {
                carriedInRow(carriedIn)
            }
            ForEach(entries.filter { !$0.isCarriedIn }) { entry in
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

    /// Carried-in entries are managed by the source month's report, so they
    /// show as one line that can't be opened or edited.
    private func carriedInRow(_ carriedIn: CarriedInTime) -> some View {
        let label = Text(carriedIn.label())
        return HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(verbatim: "↘")
                .accessibilityHidden(true)
            label
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
