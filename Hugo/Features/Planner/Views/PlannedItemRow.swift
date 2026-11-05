import SwiftUI

/// One plan in the day sheet, as a card. The card's main part opens the plan
/// form. On a day that has started it also shows the plan's fill, and a Log
/// button while the plan still has time left.
struct PlannedItemRow: View {
    let item: PlannedItem
    var bar: PlannerBar? = nil
    var showsProgress = false
    let onEdit: () -> Void
    var onLog: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var color: Color {
        guard let color = item.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    private var startTimeText: String? {
        guard let minute = item.startMinute,
            let time = Calendar.current.date(
                bySettingHour: minute / 60, minute: minute % 60, second: 0, of: item.day.startDate())
        else { return nil }
        return time.formatted(date: .omitted, time: .shortened)
    }

    /// For example "1 hour of 2 hours logged". Nil unless the day sheet asks for progress.
    private var progressText: String? {
        guard showsProgress, let bar else { return nil }
        let logged = ServiceDurationFormatter.hoursString(from: bar.filledSeconds)
        let planned = ServiceDurationFormatter.hoursString(from: bar.seconds)
        return String(
            localized: "planner.plan.progress", defaultValue: "\(logged) of \(planned) logged",
            comment: "On a plan in the Planner day sheet: how much of the plan is logged. Logged time, planned time.")
    }

    /// Everything the card says, for the edit button's VoiceOver value.
    private var valueText: String {
        var parts = [ServiceDurationFormatter.accessibilityString(from: item.duration)]
        if let startTimeText {
            parts.append(startTimeText)
        }
        if let progressText {
            parts.append(progressText)
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            HStack(spacing: HugoLayout.Spacing.spacious) {
                Button(action: onEdit) {
                    HStack(spacing: HugoLayout.Spacing.spacious) {
                        Image(systemName: item.categoryIconName)
                            .font(.title2)
                            .fontWeight(.medium)
                            .frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)
                        VStack(alignment: .leading) {
                            Text(ServiceDurationFormatter.hoursString(from: item.duration))
                                .font(.body)
                                .fontWeight(.bold)
                            Text(item.categoryName)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            if let startTimeText {
                                Label(startTimeText, systemImage: "clock")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(item.categoryName))
                .accessibilityValue(Text(valueText))
                .accessibilityHint(Text("planner.plan.edit.hint"))

                if let onLog {
                    Button("planner.plan.log", action: onLog)
                        .buttonStyle(.bordered)
                        .tint(.hugoAccent)
                        .accessibilityLabel(Text("planner.plan.log.a11y"))
                }
            }

            if let bar {
                PlannerBarShape(fraction: bar.fraction, color: color)
                    .frame(maxWidth: .infinity)
                    .frame(height: HugoLayout.Size.calendarBarHeight)
                    .accessibilityHidden(true)
            }
            if let progressText {
                Text(progressText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, HugoLayout.Spacing.card)
        .padding(.horizontal, HugoLayout.Spacing.card)
        .background(
            colorScheme == .dark
                ? Color(.secondarySystemBackground)
                : Color(.systemBackground)
        )
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
    }
}
