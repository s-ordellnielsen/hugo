import SwiftUI

struct PlannerDayCell: View {
    let day: PlannerDay

    @ScaledMetric(relativeTo: .body) private var numberDiameter = HugoLayout.Size.calendarDayNumber
    @ScaledMetric(relativeTo: .body) private var minHeight = HugoLayout.Size.calendarDayMinHeight

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.tight) {
            Text(String(day.id.day))
                .font(.body)
                .fontWeight(day.isToday ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(numberStyle)
                .frame(width: numberDiameter, height: numberDiameter)
                .background {
                    if day.isToday {
                        Circle().fill(.primary)
                    }
                }
            ForEach(visibleBars) { bar in
                PlannerBarView(bar: bar)
            }
            if hiddenBarCount > 0 {
                Text(verbatim: "+\(hiddenBarCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.id.startDate(), format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(Text(accessibilityValue))
    }

    /// Up to three bars; with four or more, the first two and a "+N" line.
    private var visibleBars: [PlannerBar] {
        day.bars.count > 3 ? Array(day.bars.prefix(2)) : day.bars
    }

    private var hiddenBarCount: Int { day.bars.count - visibleBars.count }

    private var numberStyle: AnyShapeStyle {
        if day.isToday { return AnyShapeStyle(Color(.systemBackground)) }
        return day.isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    /// Every bar, also the hidden ones, so VoiceOver users get the whole day.
    private var accessibilityValue: String {
        guard !day.bars.isEmpty else {
            return String(
                localized: "planner.day.a11y.empty", defaultValue: "Nothing planned or logged",
                comment: "VoiceOver value of a calendar day with no plans and no entries.")
        }
        return day.bars.map { bar in
            let name = bar.categoryName
            let logged = ServiceDurationFormatter.accessibilityString(from: bar.filledSeconds)
            switch bar.kind {
            case .plan:
                let planned = ServiceDurationFormatter.accessibilityString(from: bar.seconds)
                return String(
                    localized: "planner.bar.a11y.plan", defaultValue: "\(name): \(logged) of \(planned) logged",
                    comment:
                        "VoiceOver text for one plan in a calendar day. Category name, logged duration, planned duration."
                )
            case .unplanned:
                return String(
                    localized: "planner.bar.a11y.unplanned", defaultValue: "\(name): \(logged) logged, not planned",
                    comment: "VoiceOver text for logged time that no plan covers. Category name, logged duration.")
            }
        }
        .joined(separator: ". ")
    }
}
