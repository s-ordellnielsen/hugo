import SwiftUI

struct PlannerTargetPreviewView: View {
    let preview: PlannerTargetPreview
    let hasGoal: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            HStack(alignment: .firstTextBaseline) {
                Text(preview.totalLabel)
                    .font(.system(.largeTitle, design: .serif, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
                    .motion(Motion.value, value: preview.totalLabel)
            }

            if hasGoal, let solid = preview.solidFraction, let extended = preview.extendedFraction,
                let marker = preview.markerFraction
            {
                MarkedProgressBar(filled: solid, extended: extended, marker: marker, trackColor: .hugoLightTrack) {
                    Text("planner.target.base.monthlyGoal")
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                    Text(preview.baseLabel)
                    if let adjustedLabel = preview.adjustedLabel {
                        Text(adjustedLabel)
                            .foregroundStyle(.secondary)
                    }
                    Text(preview.bufferLabel)
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)

            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(hasGoal ? preview.accessibilityDescription : preview.accessibilityDescriptionWithoutGoal))
    }
}
