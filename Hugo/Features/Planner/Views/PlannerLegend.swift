import SwiftUI

/// Explains the two bar states under the grid: an empty bar is planned time,
/// a full bar is logged time.
struct PlannerLegend: View {
    var body: some View {
        HStack(spacing: HugoLayout.Spacing.spacious) {
            legendItem(fraction: 0, title: "planner.legend.planned")
            legendItem(fraction: 1, title: "planner.legend.logged")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(fraction: Double, title: LocalizedStringKey) -> some View {
        HStack(spacing: HugoLayout.Spacing.small) {
            PlannerBarShape(fraction: fraction, color: .hugoAccent)
                .frame(width: 24, height: 6)
                .accessibilityHidden(true)
            Text(title)
        }
    }
}
