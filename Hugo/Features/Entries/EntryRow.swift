import SwiftUI

struct EntryRow: View {
    @Environment(\.colorScheme) var colorScheme

    var entry: Entry
    @Binding var selectedEntry: Entry?

    private var accessibilityValue: Text {
        let duration = ServiceDurationFormatter.accessibilityString(from: entry.duration)

        guard entry.bibleStudies != 0 else {
            return Text(verbatim: duration)
        }

        let bibleStudies = String(localized: "entry.bibelstudies.count.accessibility.\(entry.bibleStudies)")

        return Text("\(duration), \(bibleStudies)")
    }

    var body: some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: HugoLayout.Spacing.spacious) {
                Image(
                    systemName: entry.tracker?.iconName ?? "questionmark.circle"
                )
                .font(.title)
                .fontWeight(.medium)
                .frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)
                .alignmentGuide(
                    .leading,
                    computeValue: { dimension in
                        dimension[.leading]
                    }
                )
                VStack(alignment: .leading) {
                    HStack(spacing: HugoLayout.Spacing.small) {
                        Text(ServiceDurationFormatter.string(from: entry.duration))
                            .fontWeight(.bold)
                        Text(
                            entry.tracker != nil
                                ? String(entry.tracker?.name ?? "") : String(localized: "entry.untracked")
                        )
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .font(.body)
                    Text(
                        entry.date,
                        format: Date.FormatStyle(
                            date: .abbreviated,
                            time: .none
                        )
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if entry.bibleStudies != 0 {
                    VStack(spacing: HugoLayout.Spacing.tight) {
                        Image(systemName: "book")
                        Text(String("\(entry.bibleStudies)"))
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                }
            }
            .padding(.vertical, HugoLayout.Spacing.card)
            .padding(.horizontal, HugoLayout.Spacing.card)
            .background(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground)
            )
            .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(entry.tracker?.name ?? String(localized: "entry.untracked")))
        .accessibilityValue(accessibilityValue)
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedEntry: Entry? = nil
    let tracker = Tracker()

    EntryRow(
        entry: Entry(date: Date(), duration: 3600, tracker: tracker, bibleStudies: 2), selectedEntry: $selectedEntry)
}
