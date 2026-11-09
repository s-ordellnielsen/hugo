import SwiftUI

/// A row of color swatches for a category: a custom color wheel, then
/// Automatic and the presets. The wheel opens two sliders, for hue and tone.
struct CategoryColorPicker: View {
    @Binding var selection: CategoryColor?
    /// Reports whether the sliders are showing, so the screen can change its footer.
    var onCustomChange: (Bool) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var swatchSize = HugoLayout.Size.colorSwatch
    /// Set when the user taps the custom wheel, so the sliders stay open
    /// even while the color happens to match a preset.
    @State private var customIsOpen = false
    /// The color while a slider is dragged. Written to `selection` when the drag ends.
    @State private var draft: CategoryColor?

    private var shown: CategoryColor? { draft ?? selection }

    private var showsSliders: Bool {
        customIsOpen || (selection != nil && CategoryColorPreset.matching(selection) == nil)
    }

    private var appearance: CategoryColor.Appearance { CategoryColor.Appearance(colorScheme) }

    private var shownHue: Double { shown?.hue ?? 0.5 }

    private var shownTone: Double { shown?.tone ?? 0.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            ScrollView(.horizontal) {
                HStack(spacing: HugoLayout.Spacing.compact) {
                    customSwatch
                    Capsule()
                        .fill(.separator)
                        .frame(width: 2, height: swatchSize * 0.75)
                        .accessibilityHidden(true)
                    swatch(color: nil, name: "tracker.color.automatic")
                    ForEach(CategoryColorPreset.all) { preset in
                        swatch(color: preset.color, name: preset.name)
                    }
                }
                .padding(.vertical, HugoLayout.Spacing.tight)
            }
            .scrollIndicators(.hidden)

            if showsSliders {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
                    GradientSlider(
                        value: hueBinding,
                        track: hueTrack,
                        thumb: CategoryColorStyle(shown),
                        label: Text("tracker.color.hue"),
                        valueText: Text(CategoryHueName(hue: shownHue).name),
                        step: 1.0 / 24,
                        wraps: true,
                        onEditingChanged: editingChanged)

                    GradientSlider(
                        value: toneBinding,
                        track: toneTrack,
                        thumb: CategoryColorStyle(shown),
                        label: Text("tracker.color.tone"),
                        valueText: Text(shownTone.formatted(.percent.precision(.fractionLength(0)))),
                        step: 0.1,
                        onEditingChanged: editingChanged)
                }
                .transition(.opacity)
            }
        }
        .motion(Motion.presence, value: showsSliders)
        .onChange(of: showsSliders, initial: true) { _, isOpen in
            onCustomChange(isOpen)
        }
    }

    private func isSelected(_ color: CategoryColor?) -> Bool {
        if showsSliders { return false }
        guard let color else { return selection == nil }
        return CategoryColorPreset.matching(selection)?.color == color
    }

    private var wheelColors: [Color] {
        (0...12).map { CategoryColor(hue: Double($0) / 12, tone: 0.5).color(for: appearance) }
    }

    private var customSwatch: some View {
        Button {
            customIsOpen = true
            if selection == nil {
                selection = CategoryColor(hue: 0.5, tone: 0.5)
            }
        } label: {
            swatchLabel(AngularGradient(colors: wheelColors, center: .center), selected: showsSliders)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("tracker.color.custom"))
        .accessibilityAddTraits(showsSliders ? [.isButton, .isSelected] : .isButton)
    }

    private func swatch(color: CategoryColor?, name: LocalizedStringResource) -> some View {
        let selected = isSelected(color)
        return Button {
            customIsOpen = false
            draft = nil
            selection = color
        } label: {
            swatchLabel(
                CategoryColorStyle(color), selected: selected, symbol: color == nil ? "sparkles" : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func swatchLabel(_ fill: some ShapeStyle, selected: Bool, symbol: String? = nil) -> some View {
        Circle()
            .fill(fill)
            .frame(width: swatchSize, height: swatchSize)
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
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

    // MARK: - Sliders

    private var hueBinding: Binding<Double> {
        Binding(
            get: { shownHue },
            set: { newHue in write(CategoryColor(hue: newHue, tone: shownTone)) })
    }

    private var toneBinding: Binding<Double> {
        Binding(
            get: { shownTone },
            set: { newTone in write(CategoryColor(hue: shownHue, tone: newTone)) })
    }

    /// During a drag the color goes to `draft`. Outside a drag (VoiceOver) it
    /// goes straight to `selection`.
    private func write(_ color: CategoryColor) {
        if draft != nil {
            draft = color
        } else {
            selection = color
        }
    }

    private func editingChanged(_ isEditing: Bool) {
        if isEditing {
            draft = selection ?? CategoryColor(hue: 0.5, tone: 0.5)
        } else {
            if let draft {
                selection = draft
            }
            draft = nil
        }
    }

    private var hueTrack: LinearGradient {
        let hues: [Double] = (0...12).map { Double($0) / 12 }
        return LinearGradient(
            colors: hues.map { CategoryColor(hue: $0, tone: shownTone).color(for: appearance) },
            startPoint: .leading,
            endPoint: .trailing)
    }

    private var toneTrack: LinearGradient {
        let tones: [Double] = [0, 0.25, 0.5, 0.75, 1]
        return LinearGradient(
            colors: tones.map { CategoryColor(hue: shownHue, tone: $0).color(for: appearance) },
            startPoint: .leading,
            endPoint: .trailing)
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

#Preview("Custom color") {
    @Previewable @State var selection: CategoryColor? = CategoryColor(hue: 0.5, tone: 0.3)

    Form {
        CategoryColorPicker(selection: $selection)
    }
}
