import SwiftUI

struct MonthlyProgressCard: View {
    let value: Double
    let monthlyGoal: Double
    var planStatus: MonthlyProgressStatus? = nil
    let onAddEntry: () -> Void
    let onShowDetails: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = HugoLayout.Typography.monthlyProgressHeroSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onShowDetails) {
                ZStack {
                    MonthlyProgressCircle(progress: value, maxValue: monthlyGoal)
                    VStack {
                        Text(Date.now, format: .dateTime.month(.wide))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(String("\(Int(value))"))
                            .font(.system(size: heroSize, weight: .bold, design: .serif))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .motion(Motion.value, value: value)
                        if let planStatus {
                            MonthlyProgressStatusView(status: planStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .buttonStyle(.card)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("a11y.monthly_progress_card.label"))
            .accessibilityValue(Text(verbatim: accessibilityValueText))

            Button(action: onAddEntry) {
                Label("entry.add.label", systemImage: "plus")
                    .padding(HugoLayout.Spacing.regular)
            }
            .buttonBorderShape(.circle)
            .font(.largeTitle)
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .hoverEffect(.lift)
            .padding(.trailing, HugoLayout.Spacing.compact)
            .padding(.bottom, HugoLayout.Spacing.compact)
        }
    }

    private var accessibilityValueText: String {
        let amount =
            monthlyGoal > 0
            ? String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(monthlyGoal))")
            : String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
        guard let planStatus else { return amount }
        return "\(amount), \(planStatus.label)"
    }
}
