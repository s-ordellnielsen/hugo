import SwiftUI
import WidgetKit

struct MonthProgressWidgetView: View {
    let state: WidgetState
    let date: Date

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
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
        .containerBackground(for: .widget) { background }
    }

    /// The medium widget draws its progress circle in the background so it can run to the widget's edge.
    @ViewBuilder
    private var background: some View {
        if family == .systemMedium, case .ready(let progress) = state {
            MediumBackground(fraction: progress.fill.fraction)
        } else {
            Rectangle().fill(.fill.tertiary)
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

/// The Overview's `MonthlyProgressCircle`, redrawn for the widget: a disc that a gradient fills from the bottom.
/// `fillHeight` is the water level as a share of the diameter, measured from the disc's bottom. The accent is
/// `Color.hugoAccent` (`.mint`), which the widget cannot take from the app's DesignSystem.
private struct ProgressCircle: View {
    let fillHeight: Double
    let isFull: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var gradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ? [.mint.opacity(0.7), .mint] : [.mint, .mint.opacity(0.55)],
            startPoint: UnitPoint(x: 0.456, y: 1),
            endPoint: UnitPoint(x: 0.544, y: 0))
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                    .frame(width: side, height: side)
                Rectangle()
                    .fill(gradient)
                    .frame(width: side, height: side)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(width: side, height: CGFloat(ceil(fillHeight * Double(side) + (isFull ? 1 : 0))))
                    }
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The medium circle is `mediumCircleScale` times as tall as the widget, centered vertically, so the widget's
/// top and bottom edges cut it. `mediumCircleVisibleShare` of its width stays in view; the left edge cuts the rest.
private let mediumCircleScale: CGFloat = 1.3
private let mediumCircleVisibleShare: CGFloat = 0.62

private struct MediumBackground: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let side = height * mediumCircleScale
            // What you see of the circle, as shares of its diameter.
            let windowHeight = 1 / Double(mediumCircleScale)
            let windowBottom = (1 - windowHeight) / 2
            let windowLeft = 1 - Double(mediumCircleVisibleShare)
            // The fraction is the share of the visible part that is filled, so the level matches what you see.
            let fillHeight = CircleFillGeometry.height(
                forVisibleAreaFraction: fraction, windowBottom: windowBottom, windowHeight: windowHeight,
                windowLeft: windowLeft)
            ZStack {
                Rectangle().fill(.fill.tertiary)
                ProgressCircle(fillHeight: fillHeight, isFull: fraction >= 1)
                    .frame(width: side, height: side)
                    .position(x: side * mediumCircleVisibleShare - side / 2, y: height / 2)
            }
        }
    }
}

private struct MediumContent: View {
    let progress: MonthProgress
    let date: Date

    @Environment(\.widgetContentMargins) private var margins

    var body: some View {
        GeometryReader { proxy in
            // The background circle is `mediumCircleScale` times as tall as the whole widget, margins included.
            let circleSide = (proxy.size.height + margins.top + margins.bottom) * mediumCircleScale
            let inset = max(0, circleSide * mediumCircleVisibleShare - margins.leading + 12)
            textColumn
                .padding(.leading, inset)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date, format: .dateTime.month(.wide))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(progress.headline.value)")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                unit
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(verbatim: detailLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    /// "hours" or "min", next to the number.
    @ViewBuilder
    private var unit: some View {
        switch progress.headline {
        case .hours(let hours): hours == 1 ? Text("widget.month.hour.unit") : Text("widget.month.hours.unit")
        case .minutes: Text("widget.month.minutes.unit")
        }
    }

    /// "4 days left · 45 hours left". Without a goal the second part is the planned time, if any.
    private var detailLine: String {
        var parts = [String(localized: "widget.month.days.left \(progress.daysLeft)")]
        if let leftHours = progress.leftHours {
            if leftHours <= 0 {
                parts.append(String(localized: "widget.month.reached"))
            } else {
                parts.append(String(localized: "widget.month.hours.left \(Int(leftHours.rounded(.up)))"))
            }
        } else if case .plan(let plannedSeconds) = progress.fill.basis {
            parts.append(
                String(localized: "widget.month.hours.planned \(ServiceDurationFormatter.wholeHours(from: plannedSeconds))"))
        }
        return parts.joined(separator: " \u{B7} ")
    }

    /// The full sentence VoiceOver reads, such as
    /// "November: 32 hours of 50 hours. 18 hours left to the goal. 4 days left in the month."
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
        parts.append(String(localized: "widget.month.a11y.days \(progress.daysLeft)"))
        return parts.joined(separator: ". ") + "."
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

#Preview("Medium, many days left", as: .systemMedium) {
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
