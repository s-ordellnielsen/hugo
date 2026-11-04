import SwiftUI

/// Explains the Planner in one sentence, shown while the month has no plans.
struct PlannerIntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("planner.intro.title")
                .font(.title3)
                .fontWeight(.semibold)
            Text("planner.intro.description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(HugoLayout.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }
}
