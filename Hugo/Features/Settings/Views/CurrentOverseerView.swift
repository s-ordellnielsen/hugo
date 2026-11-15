import SwiftUI

/// The top of the group overseer settings: a large symbol, the overseer's
/// name in serif and their phone number, or a short explanation when no
/// overseer is set. Matches `CurrentPublisherStatusView`.
struct CurrentOverseerView: View {
    let fullName: String
    let phoneNumber: String

    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = HugoLayout.Size.prominentSymbol

    private var hasOverseer: Bool { !fullName.isEmpty }

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.spacious) {
            Image(systemName: hasOverseer ? "person.crop.circle.fill" : "person.crop.circle.badge.questionmark")
                .font(.system(size: symbolSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(hasOverseer ? Color.hugoAccent : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            VStack(spacing: HugoLayout.Spacing.compact) {
                Text(hasOverseer ? fullName : String(localized: "report.overseer.empty"))
                    .font(.system(.title, design: .serif, weight: .bold))
                    .contentTransition(.opacity)

                Text(hasOverseer ? phoneNumber : String(localized: "overseer.header.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .motion(Motion.presence, value: fullName)
    }
}

#Preview {
    List {
        CurrentOverseerView(fullName: "Anna Berg", phoneNumber: "+45 12 34 56 78")
            .listRowBackground(Color.clear)
        CurrentOverseerView(fullName: "", phoneNumber: "")
            .listRowBackground(Color.clear)
    }
}
