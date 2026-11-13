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
                        heroAmount
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

    /// The month's total as the hero shows it: minutes under an hour, whole hours above.
    private var headline: HeadlineDuration {
        HeadlineDuration(seconds: (value * 3_600).rounded())
    }

    private var heroAmount: some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.tight) {
            Text(String("\(headline.value)"))
                .font(.system(size: heroSize, weight: .bold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .motion(Motion.value, value: value)
            if case .minutes = headline {
                Text("duration.minutesUnit")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accessibilityValueText: String {
        if case .minutes = headline {
            let minutes = headline.spokenText()
            return switch fill.basis {
            case .monthlyGoal(let hours):
                String(localized: "a11y.monthly_progress_card.value.minutes.\(minutes).\(Int(hours))")
            case .plan(let plannedSeconds):
                String(
                    localized:
                        "a11y.monthly_progress_card.value.minutes.planned.\(minutes).\(Int((plannedSeconds / 3_600).rounded(.up)))"
                )
            case .presence:
                String(localized: "a11y.monthly_progress_card.value.minutes.\(minutes)")
            }
        }
        return switch fill.basis {
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
