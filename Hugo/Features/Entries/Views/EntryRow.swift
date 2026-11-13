import SwiftUI

struct EntryRow: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = HugoLayout.Size.entryIcon

    var entry: Entry
    @Binding var selectedEntry: Entry?

    private var accessibilityValue: Text {
        Text(verbatim: EntryAccessibilityValue.text(duration: entry.duration, bibleStudies: entry.bibleStudies))
    }

    private var category: EntryCategory { entry.resolvedCategory() }

    /// Duration and category name on one line normally; on two lines at
    /// accessibility sizes, so neither wraps word by word.
    private var titleLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: HugoLayout.Spacing.small))
    }

    var body: some View {
        Button {
            selectedEntry = entry
        } label: {
            HStack(spacing: HugoLayout.Spacing.spacious) {
                ZStack {
                    Image(systemName: category.iconName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .frame(width: iconSize, height: iconSize)
                        .alignmentGuide(
                            .leading,
                            computeValue: { dimension in
                                dimension[.leading]
                            }
                        )
                }
                .frame(width: iconSize, height: iconSize)
                VStack(alignment: .leading) {
                    titleLayout {
                        Text(ServiceDurationFormatter.string(from: entry.duration))
                            .fontWeight(.bold)
                        Text(category.name)
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
        .accessibilityLabel(Text(category.name))
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
