import SwiftUI

struct MonthlyProgressCard: View {
    let value: Double
    let fill: MonthlyCircleFill
    var planStatus: MonthlyProgressStatus? = nil
    let onAddEntry: () -> Void
    let onShowPlanPace: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = HugoLayout.Typography.monthlyProgressHeroSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                MonthlyProgressCircle(fraction: fill.fraction)
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
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
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("a11y.monthly_progress_card.label"))
                    .accessibilityValue(Text(verbatim: accessibilityValueText))

                    if let planStatus {
                        Button(action: onShowPlanPace) {
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                MonthlyProgressStatusView(status: planStatus)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .accessibilityHidden(true)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.card)
                        .accessibilityLabel(Text(verbatim: planStatus.label))
                        .accessibilityHint(Text("overview.pace.a11y.hint"))
                        .transition(.opacity)
                    }
                }
            }

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
        switch fill.basis {
        case .monthlyGoal(let hours):
            String(localized: "a11y.monthly_progress_card.value.\(Int(value)).\(Int(hours))")
        case .plan(let plannedSeconds):
            String(
                localized:
                    "a11y.monthly_progress_card.value.planned.\(Int(value)).\(Int((plannedSeconds / 3_600).rounded(.up)))"
            )
        case .presence:
            String(localized: "a11y.monthly_progress_card.value.\(Int(value))")
        }
    }
}
