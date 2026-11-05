import SwiftUI

/// One category's plans on a day, as a card in the day sheet. Hugo matches
/// logged time per category, not per plan, so the card has one bar, one
/// progress line and one Log button for all of them. With one plan, the card's
/// main part opens it. With several, each plan is a line that opens it.
struct PlannedCategoryCard: View {
    let bar: PlannerBar
    var showsProgress = false
    let onEdit: (PlannedItem) -> Void
    var onLog: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var color: Color {
        guard let color = bar.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    /// The plan when the category has exactly one on the day.
    private var singleItem: PlannedItem? {
        bar.items.count == 1 ? bar.items.first : nil
    }

    /// For example "1 hour of 2 hours logged". Nil unless the day sheet asks for progress.
    private var progressText: String? {
        guard showsProgress else { return nil }
        let logged = ServiceDurationFormatter.hoursString(from: bar.filledSeconds)
        let planned = ServiceDurationFormatter.hoursString(from: bar.seconds)
        return String(
            localized: "planner.plan.progress", defaultValue: "\(logged) of \(planned) logged",
            comment: "On a plan in the Planner day sheet: how much of the plan is logged. Logged time, planned time.")
    }

    private func startTimeText(for item: PlannedItem) -> String? {
        guard let minute = item.startMinute,
            let time = Calendar.current.date(
                bySettingHour: minute / 60, minute: minute % 60, second: 0, of: item.day.startDate())
        else { return nil }
        return time.formatted(date: .omitted, time: .shortened)
    }

    /// A gray track filled from the left in the category's color. Unlike the
    /// calendar's bars it has no outline: on a bar this wide, an outline reads
    /// as a dark border around the unfilled part.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.secondarySystemFill))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * bar.fraction)
            }
        }
    }

    /// Everything the header says, for VoiceOver.
    private var headerValue: String {
        var parts = [ServiceDurationFormatter.accessibilityString(from: bar.seconds)]
        if let singleItem, let startTime = startTimeText(for: singleItem) {
            parts.append(startTime)
        }
        if let progressText {
            parts.append(progressText)
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            HStack(spacing: HugoLayout.Spacing.spacious) {
                if let singleItem {
                    Button {
                        onEdit(singleItem)
                    } label: {
                        header(startTime: startTimeText(for: singleItem))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(bar.categoryName))
                    .accessibilityValue(Text(headerValue))
                    .accessibilityHint(Text("planner.plan.edit.hint"))
                } else {
                    header(startTime: nil)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(bar.categoryName))
                        .accessibilityValue(Text(headerValue))
                }

                if let onLog {
                    Button("planner.plan.log", action: onLog)
                        .buttonStyle(.bordered)
                        .tint(.hugoAccent)
                        .accessibilityLabel(Text("planner.plan.log.a11y"))
                }
            }

            if singleItem == nil {
                VStack(spacing: 0) {
                    ForEach(bar.items) { item in
                        line(item)
                    }
                }
            }

            progressBar
                .frame(height: HugoLayout.Size.calendarBarHeight)
                .accessibilityHidden(true)
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

    private func header(startTime: String?) -> some View {
        HStack(spacing: HugoLayout.Spacing.spacious) {
            Image(systemName: bar.categoryIconName)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: HugoLayout.Size.entryIcon, height: HugoLayout.Size.entryIcon)
            VStack(alignment: .leading) {
                Text(ServiceDurationFormatter.hoursString(from: bar.seconds))
                    .font(.body)
                    .fontWeight(.bold)
                Text(bar.categoryName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let startTime {
                    Label(startTime, systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    /// One plan of several: its start time and duration. Opens the plan.
    private func line(_ item: PlannedItem) -> some View {
        let startTime = startTimeText(for: item)
        let duration = ServiceDurationFormatter.hoursString(from: item.duration)
        return Button {
            onEdit(item)
        } label: {
            HStack(spacing: HugoLayout.Spacing.regular) {
                if let startTime {
                    Label(startTime, systemImage: "clock")
                        .foregroundStyle(.secondary)
                } else {
                    Text("planner.plan.noStartTime")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: HugoLayout.Spacing.compact)
                Text(duration)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
            .padding(.leading, HugoLayout.Size.entryIcon + HugoLayout.Spacing.spacious)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(startTime.map { Text($0) } ?? Text("planner.plan.noStartTime"))
        .accessibilityValue(Text(ServiceDurationFormatter.accessibilityString(from: item.duration)))
        .accessibilityHint(Text("planner.plan.edit.hint"))
    }
}
