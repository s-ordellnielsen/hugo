import SwiftUI

/// The day's logged entries in the Planner day sheet: a small header with the
/// day's logged total and one compact row per entry. Secondary to the plans
/// above it; tapping a row opens the entry.
struct PlannerLoggedEntryList: View {
    let entries: [Entry]
    let total: TimeInterval
    let onSelect: (Entry) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var header: String {
        let total = ServiceDurationFormatter.hoursString(from: total)
        return String(
            localized: "planner.day.logged.header", defaultValue: "Logged · \(total)",
            comment: "Header above the logged entries in the Planner day sheet. The day's logged time in words.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            Text(header)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider()
                            .padding(
                                .leading,
                                HugoLayout.Spacing.spacious + HugoLayout.Size.labelReservedIconWidth
                                    + HugoLayout.Spacing.regular)
                    }
                    row(entry)
                }
            }
            .background(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground)
                    : Color(.systemBackground)
            )
            .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
        }
    }

    private func row(_ entry: Entry) -> some View {
        let category = entry.resolvedCategory()
        return Button {
            onSelect(entry)
        } label: {
            HStack(spacing: HugoLayout.Spacing.regular) {
                Image(systemName: category.iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: HugoLayout.Size.labelReservedIconWidth)
                Text(category.name)
                Spacer(minLength: HugoLayout.Spacing.compact)
                Text(ServiceDurationFormatter.hoursString(from: entry.duration))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .padding(.vertical, HugoLayout.Spacing.regular)
            .padding(.horizontal, HugoLayout.Spacing.spacious)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(category.name))
        .accessibilityValue(Text(ServiceDurationFormatter.accessibilityString(from: entry.duration)))
    }
}
