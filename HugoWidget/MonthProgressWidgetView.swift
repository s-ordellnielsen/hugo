import SwiftUI
import WidgetKit

struct MonthProgressWidgetView: View {
    let state: WidgetState
    let date: Date

    var body: some View {
        switch state {
        case .ready(let progress):
            ReadyContent(progress: progress, date: date)
        case .unavailable:
            UnavailableContent()
        }
    }
}

private struct ReadyContent: View {
    let progress: MonthProgress
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date, format: .dateTime.month(.wide))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(progress.headline.value)")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if case .minutes = progress.headline {
                    Text("widget.month.minutes.unit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            goalLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var goalLine: some View {
        switch progress.fill.basis {
        case .monthlyGoal(let hours):
            VStack(alignment: .leading, spacing: 4) {
                Text("widget.month.of.goal \(Int(hours))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Matches `Color.hugoAccent`, which the widget cannot use from the app's DesignSystem.
                Gauge(value: progress.fill.fraction) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.mint)
            }
        case .plan(let plannedSeconds):
            Text("widget.month.of.planned \(ServiceDurationFormatter.wholeHours(from: plannedSeconds))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .presence:
            EmptyView()
        }
    }

    /// The full sentence VoiceOver reads, such as "November: 32 hours of 50 hours".
    private var accessibilityText: String {
        let month = date.formatted(.dateTime.month(.wide))
        let time = progress.headline.spokenText()
        switch progress.fill.basis {
        case .monthlyGoal(let hours):
            let goal = ServiceDurationFormatter.hoursString(from: hours * 3_600)
            return String(localized: "widget.month.a11y.goal \(month) \(time) \(goal)")
        case .plan(let plannedSeconds):
            let planned = ServiceDurationFormatter.hoursString(from: plannedSeconds)
            return String(localized: "widget.month.a11y.plan \(month) \(time) \(planned)")
        case .presence:
            return String(localized: "widget.month.a11y.nogoal \(month) \(time)")
        }
    }
}

private struct UnavailableContent: View {
    var body: some View {
        Label {
            Text("widget.month.setup")
        } icon: {
            Image(systemName: "chart.pie")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.month.a11y.unavailable"))
    }
}

#Preview(as: .systemSmall) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .ready(MonthProgress.sample))
}

#Preview("No goal", as: .systemSmall) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(
        date: .now,
        state: .ready(
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: 12 * 3_600, goalHours: 0,
                fill: MonthlyCircleFill(basis: .plan(plannedSeconds: 20 * 3_600), fraction: 0.6))))
}

#Preview("Minutes", as: .systemSmall) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(
        date: .now,
        state: .ready(
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: 45 * 60, goalHours: 50,
                fill: MonthlyCircleFill(basis: .monthlyGoal(hours: 50), fraction: 0.015))))
}

#Preview("Unavailable", as: .systemSmall) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .unavailable)
}
