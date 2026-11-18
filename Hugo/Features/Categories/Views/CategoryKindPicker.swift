import SwiftUI

/// Picks a category's kind on two cards, Field Service and Credit, and says
/// under them what the chosen kind means for the report, the yearly goal and
/// Bible studies. Put it in a `Form` section; it draws its own card
/// backgrounds, so the section row is cleared (see `categoryKindRow()`).
struct CategoryKindPicker: View {
    @Binding var kind: TrackerType

    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @Environment(\.locale) private var locale

    private var facts: [CategoryKindFact] {
        CategoryKindFact.facts(for: kind, status: PublisherStatus.status(for: statusID), locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
            VStack(spacing: HugoLayout.Spacing.compact) {
                ForEach(TrackerType.allCases) { option in
                    card(for: option)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("tracker.type.label.long"))

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                ForEach(facts) { fact in
                    Label {
                        Text(fact.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: fact.systemImage)
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, HugoLayout.Spacing.spacious)
        }
        .motion(Motion.value, value: kind)
        .sensoryFeedback(.selection, trigger: kind)
    }

    private func card(for option: TrackerType) -> some View {
        let isSelected = option == kind
        let shape = RoundedRectangle(cornerRadius: HugoLayout.CornerRadius.compactCard, style: .continuous)
        return Button {
            kind = option
        } label: {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
                    Image(systemName: CategoryKindFact.systemImage(for: option))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.hugoAccent) : AnyShapeStyle(.secondary))
                    Text(option.label)
                        .font(.headline)
                    Spacer(minLength: HugoLayout.Spacing.compact)
                    Checkmark(checked: isSelected)
                }
                Text(option.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(CategoryKindFact.example(for: option, locale: locale))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(HugoLayout.Spacing.spacious)
            .frame(maxWidth: .infinity, minHeight: HugoLayout.Size.minimumHitTarget, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Color.hugoAccent : Color.clear, lineWidth: 2)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// Clears a `Form` row so the kind picker's cards sit on the grouped background.
    func categoryKindRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}

#Preview("In a form") {
    @Previewable @State var kind: TrackerType = .main
    Form {
        Section {
            CategoryKindPicker(kind: $kind)
                .categoryKindRow()
        } header: {
            Text("tracker.type.label.long")
        }
    }
    .defaultAppStorage(UserDefaults(suiteName: "CategoryKindPickerPreview")!)
}

#Preview("Danish, largest text") {
    @Previewable @State var kind: TrackerType = .separate
    Form {
        Section {
            CategoryKindPicker(kind: $kind)
                .categoryKindRow()
        }
    }
    .environment(\.locale, Locale(identifier: "da_DK"))
    .dynamicTypeSize(.accessibility5)
}

#Preview("Dark") {
    @Previewable @State var kind: TrackerType = .separate
    Form {
        Section {
            CategoryKindPicker(kind: $kind)
                .categoryKindRow()
        }
    }
    .preferredColorScheme(.dark)
}
