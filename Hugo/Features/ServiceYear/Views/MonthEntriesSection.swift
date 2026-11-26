import SwiftData
import SwiftUI

/// The entries of one month on the month detail page. Carried-in time shows
/// as one line; other entries open their detail page and swipe to delete.
struct MonthEntriesSection: View {
    @Environment(\.modelContext) private var context

    let month: ServiceMonth

    @State private var deletionError: String?

    private var entries: [Entry] { month.summary?.entries ?? [] }

    var body: some View {
        let carriedIn = CarriedInTime(entries: entries)
        let logged = entries.filter { !$0.isCarriedIn }

        Section("monthDetail.section.entries") {
            if let carriedIn {
                carriedInRow(carriedIn)
            }

            if logged.isEmpty, carriedIn == nil {
                Text("overview.entries.empty")
                    .foregroundStyle(.secondary)
            }

            ForEach(logged) { entry in
                NavigationLink(destination: EntryDetailView(entry: entry)) {
                    entryRow(entry)
                }
                .swipeActions {
                    Button("entry.delete.label", systemImage: "trash", role: .destructive) {
                        delete(entry)
                    }
                }
                .entryContextMenu(entry)
            }
        }
        .alert(
            "common.error",
            isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })
        ) {
            Button("common.ok") { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
    }

    private func entryRow(_ entry: Entry) -> some View {
        Label {
            HStack {
                Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .none))
                Spacer()
                if month.isUnreported(entry) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("report.status.unreported-entries")
                }
                Text(ServiceDurationFormatter.string(from: entry.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: entry.resolvedCategory().iconName)
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

    private func delete(_ entry: Entry) {
        do {
            try context.performIsolatedChange { context.delete(entry) }
        } catch {
            deletionError = error.localizedDescription
        }
    }
}
