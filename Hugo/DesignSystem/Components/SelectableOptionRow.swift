import SwiftUI

struct SelectableOptionRow: View {
    let title: Text
    var description: Text? = nil
    var value: Text? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: HugoLayout.Spacing.regular) {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    title.font(.body).foregroundStyle(.primary)
                    if let description {
                        description.font(.footnote).foregroundStyle(.secondary).fixedSize(
                            horizontal: false, vertical: true)
                    }
                    if let value, dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact {
                        value.font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: HugoLayout.Spacing.compact)
                if let value, !dynamicTypeSize.isAccessibilitySize, horizontalSizeClass != .compact {
                    value.font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Checkmark(checked: isSelected).accessibilityHidden(true)
            }
            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
