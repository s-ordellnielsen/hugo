import SwiftUI
import WidgetKit

struct MonthProgressWidgetView: View {
    let state: WidgetState
    let date: Date

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch state {
        case .ready(let progress):
            if family == .systemMedium {
                MediumContent(progress: progress, date: date)
            } else {
                ReadyContent(progress: progress, date: date)
            }
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

/// A circular progress ring. Matches the Overview circle's accent (`Color.hugoAccent`, which the widget cannot
/// use from the app's DesignSystem) with a faded track and a gradient that darkens toward the start.
private struct ProgressRing<Content: View>: View {
    let fraction: Double
    @ViewBuilder let content: Content

    private var clampedFraction: Double { min(max(fraction, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let lineWidth = side * 0.11
            ZStack {
                Circle()
                    .stroke(Color.mint.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: clampedFraction)
                    .stroke(
                        AngularGradient(colors: [.mint.opacity(0.55), .mint], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                content
                    .padding(lineWidth * 1.3)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct MediumContent: View {
    let progress: MonthProgress
    let date: Date

    var body: some View {
        HStack(spacing: 16) {
            ProgressRing(fraction: progress.fill.fraction) {
                VStack(spacing: 0) {
                    Text(date, format: .dateTime.month(.wide))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(verbatim: "\(progress.headline.value)")
                        .font(.system(.title, design: .serif, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if case .minutes = progress.headline {
                        Text("widget.month.minutes.unit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let leftHours = progress.leftHours {
                    stat("widget.month.left.title") {
                        if leftHours <= 0 {
                            Text("widget.month.reached")
                        } else {
                            Text("widget.month.left.value \(Int(leftHours.rounded(.up)))")
                        }
                    }
                }
                if let pace = Pace(hours: progress.paceHours) {
                    stat("widget.month.pace.title") {
                        switch pace {
                        case .ahead(let hours): Text("widget.month.pace.ahead \(hours)")
                        case .behind(let hours): Text("widget.month.pace.behind \(hours)")
                        case .onPace: Text("widget.month.pace.on")
                        }
                    }
                }
                stat("widget.month.days.title") {
                    Text(verbatim: "\(progress.daysLeft)")
                }
                if case .plan(let plannedSeconds) = progress.fill.basis {
                    Text("widget.month.of.planned \(ServiceDurationFormatter.wholeHours(from: plannedSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func stat<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            value()
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// The full sentence VoiceOver reads, such as
    /// "November: 32 hours of 50 hours. 18 hours left to the goal. 4 hours ahead. 4 days left in the month."
    private var accessibilityText: String {
        let month = date.formatted(.dateTime.month(.wide))
        let time = progress.headline.spokenText()
        var parts: [String]
        switch progress.fill.basis {
        case .monthlyGoal(let hours):
            let goal = ServiceDurationFormatter.hoursString(from: hours * 3_600)
            parts = [String(localized: "widget.month.a11y.goal \(month) \(time) \(goal)")]
        case .plan(let plannedSeconds):
            let planned = ServiceDurationFormatter.hoursString(from: plannedSeconds)
            parts = [String(localized: "widget.month.a11y.plan \(month) \(time) \(planned)")]
        case .presence:
            parts = [String(localized: "widget.month.a11y.nogoal \(month) \(time)")]
        }
        if let leftHours = progress.leftHours {
            if leftHours <= 0 {
                parts.append(String(localized: "widget.month.reached"))
            } else {
                let left = ServiceDurationFormatter.hoursString(from: leftHours * 3_600)
                parts.append(String(localized: "widget.month.a11y.left \(left)"))
            }
        }
        switch Pace(hours: progress.paceHours) {
        case .ahead(let hours): parts.append(String(localized: "widget.month.pace.ahead \(hours)"))
        case .behind(let hours): parts.append(String(localized: "widget.month.pace.behind \(hours)"))
        case .onPace: parts.append(String(localized: "widget.month.pace.on"))
        case nil: break
        }
        parts.append(String(localized: "widget.month.a11y.days \(progress.daysLeft)"))
        return parts.joined(separator: ". ") + "."
    }
}

/// `MonthProgress.paceHours` in whole hours. A difference that rounds to 0 is on pace.
private enum Pace {
    case ahead(Int)
    case behind(Int)
    case onPace

    init?(hours: Double?) {
        guard let hours else { return nil }
        let whole = Int(hours.rounded())
        self = whole > 0 ? .ahead(whole) : whole < 0 ? .behind(-whole) : .onPace
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

#Preview("Medium", as: .systemMedium) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .ready(MonthProgress.sample))
}

#Preview("Medium, no goal", as: .systemMedium) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .ready(
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: 12 * 3_600, goalHours: 0,
                fill: MonthlyCircleFill(basis: .plan(plannedSeconds: 20 * 3_600), fraction: 0.6),
                leftHours: nil, paceHours: nil, daysLeft: 4)))
}

#Preview("Medium, minutes", as: .systemMedium) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .ready(
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: 45 * 60, goalHours: 50,
                fill: MonthlyCircleFill(basis: .monthlyGoal(hours: 50), fraction: 0.015),
                leftHours: 49.25, paceHours: -20, daysLeft: 26)))
}

#Preview("Medium, goal reached", as: .systemMedium) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .ready(
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: 52 * 3_600, goalHours: 50,
                fill: MonthlyCircleFill(basis: .monthlyGoal(hours: 50), fraction: 1),
                leftHours: 0, paceHours: 2, daysLeft: 4)))
}

#Preview("Medium, behind pace", as: .systemMedium) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .ready(
            MonthProgress(
                month: YearMonth(year: 2026, month: 11), loggedSeconds: 20 * 3_600, goalHours: 50,
                fill: MonthlyCircleFill(basis: .monthlyGoal(hours: 50), fraction: 0.4),
                leftHours: 30, paceHours: -12, daysLeft: 10)))
}

#Preview("Medium, unavailable", as: .systemMedium) {
    MonthProgressWidget()
} timeline: {
    MonthProgressEntry(date: .now, state: .unavailable)
}
