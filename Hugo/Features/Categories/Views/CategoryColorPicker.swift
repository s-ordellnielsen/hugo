import SwiftUI

/// A row of color swatches for a category: Automatic, then the presets.
struct CategoryColorPicker: View {
    @Binding var selection: CategoryColor?

    @ScaledMetric(relativeTo: .body) private var swatchSize = HugoLayout.Size.colorSwatch

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: HugoLayout.Spacing.compact) {
                swatch(color: nil, name: "tracker.color.automatic")
                ForEach(CategoryColorPreset.all) { preset in
                    swatch(color: preset.color, name: preset.name)
                }
            }
            .padding(.vertical, HugoLayout.Spacing.tight)
        }
        .scrollIndicators(.hidden)
    }

    private func isSelected(_ color: CategoryColor?) -> Bool {
        guard let color else { return selection == nil }
        return CategoryColorPreset.matching(selection)?.color == color
    }

    private func swatch(color: CategoryColor?, name: LocalizedStringResource) -> some View {
        let selected = isSelected(color)
        return Button {
            selection = color
        } label: {
            Circle()
                .fill(CategoryColorStyle(color))
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    if color == nil {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(HugoLayout.Spacing.tight)
                .overlay {
                    Circle().strokeBorder(.primary, lineWidth: 2.5).opacity(selected ? 1 : 0)
                }
                .frame(minWidth: HugoLayout.Size.minimumHitTarget, minHeight: HugoLayout.Size.minimumHitTarget)
                .contentShape(Circle())
                .motion(Motion.feedback, value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var selection: CategoryColor? = nil

    Form {
        CategoryColorPicker(selection: $selection)
    }
}

#Preview("Blue selected") {
    @Previewable @State var selection: CategoryColor? = CategoryColorPreset.all[0].color

    Form {
        CategoryColorPicker(selection: $selection)
    }
}
