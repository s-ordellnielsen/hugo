import Foundation

nonisolated struct PlannerTargetPreview: Equatable, Sendable {
    let goalSeconds: TimeInterval?
    let scaleSeconds: TimeInterval?
    let monthlyBaseSeconds: TimeInterval
    let adjustedBaseSeconds: TimeInterval
    let bufferSeconds: TimeInterval
    let totalSeconds: TimeInterval?
    let solidFraction: Double?
    let extendedFraction: Double?
    let markerFraction: Double?
    let accessibilityDescription: String
    let accessibilityDescriptionWithoutGoal: String
    let baseLabel: String
    let adjustedLabel: String?
    let bufferLabel: String
    let totalLabel: String

    static func make(
        base: PlannerTargetBase,
        extraHours: Int,
        status: PublisherStatus?,
        creditedBeforeCurrentMonth: TimeInterval,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> PlannerTargetPreview {
        let month = now.yearMonth(using: calendar)
        let monthlyGoalSeconds = TimeInterval(status?.monthlyGoal ?? 0) * 3_600
        let goalSeconds = monthlyGoalSeconds > 0 ? monthlyGoalSeconds : nil
        let monthlyBaseSeconds =
            PlannerTarget.seconds(
                for: month, base: .monthlyGoal, extraHours: 0, status: status,
                creditedBeforeCurrentMonth: creditedBeforeCurrentMonth, now: now, calendar: calendar) ?? 0
        let adjustedBaseSeconds =
            PlannerTarget.seconds(
                for: month, base: .yearlyGoalShare, extraHours: 0, status: status,
                creditedBeforeCurrentMonth: creditedBeforeCurrentMonth, now: now, calendar: calendar) ?? 0
        let selectedBaseSeconds = base == .yearlyGoalShare ? adjustedBaseSeconds : monthlyBaseSeconds
        let bufferSeconds = TimeInterval(max(0, extraHours)) * 3_600
        let totalSeconds = PlannerTarget.seconds(
            for: month, base: base, extraHours: extraHours, status: status,
            creditedBeforeCurrentMonth: creditedBeforeCurrentMonth, now: now, calendar: calendar)
        let largestBase = max(goalSeconds ?? 0, max(monthlyBaseSeconds, adjustedBaseSeconds))
        let scale = goalSeconds.map { _ in max(1.25 * largestBase, largestBase + bufferSeconds) }
        let scaleSeconds = scale
        let solidFraction = scale.map { selectedBaseSeconds / $0 }
        let extendedFraction = scale.map { (selectedBaseSeconds + bufferSeconds) / $0 }
        let markerFraction = scale.map { (goalSeconds ?? 0) / $0 }
        let totalText =
            totalSeconds.map { ServiceDurationFormatter.hoursString(from: $0, locale: locale) }
            ?? String(localized: LocalizedStringResource("planner.target.none", locale: locale))
        let baseText = ServiceDurationFormatter.hoursString(from: monthlyBaseSeconds, locale: locale)
        let bufferText = ServiceDurationFormatter.hoursString(from: bufferSeconds, locale: locale)
        let baseLabel = String(
            localized: LocalizedStringResource(
                "planner.target.preview.base", defaultValue: "Base target: \(baseText)", locale: locale))
        let bufferLabel = String(
            localized: LocalizedStringResource(
                "planner.target.preview.buffer", defaultValue: "Buffer: \(bufferText)", locale: locale))
        // The signed change from the monthly goal, only while the adjusted
        // option is chosen and the status has a yearly goal.
        let adjustedAmount: String? = {
            guard base == .yearlyGoalShare, status?.yearlyGoalRule != nil else { return nil }
            let change = adjustedBaseSeconds - monthlyBaseSeconds
            if change == 0 {
                return String(
                    localized: LocalizedStringResource("planner.target.preview.adjusted.noChange", locale: locale))
            }
            let amount = ServiceDurationFormatter.hoursString(from: abs(change), locale: locale)
            return (change > 0 ? "+" : "\u{2212}") + amount
        }()
        let adjustedLabel = adjustedAmount.map { amount in
            String(
                localized: LocalizedStringResource(
                    "planner.target.preview.adjusted", defaultValue: "Adjusted: \(amount)", locale: locale))
        }
        let accessibleBase = ServiceDurationFormatter.accessibilityString(from: monthlyBaseSeconds, locale: locale)
        let accessibleBuffer = ServiceDurationFormatter.accessibilityString(from: bufferSeconds, locale: locale)
        let accessibleTotal =
            totalSeconds.map { ServiceDurationFormatter.accessibilityString(from: $0, locale: locale) }
            ?? String(localized: LocalizedStringResource("planner.target.none", locale: locale))
        let accessibilityDescription: String
        if let adjustedAmount {
            accessibilityDescription = String(
                localized: LocalizedStringResource(
                    "planner.target.preview.accessibility.adjusted",
                    defaultValue:
                        "Base target: \(accessibleBase). Adjusted: \(adjustedAmount). Buffer: \(accessibleBuffer). Target: \(accessibleTotal).",
                    locale: locale))
        } else {
            accessibilityDescription = String(
                localized: LocalizedStringResource(
                    "planner.target.preview.accessibility",
                    defaultValue:
                        "Base target: \(accessibleBase). Buffer: \(accessibleBuffer). Target: \(accessibleTotal).",
                    locale: locale))
        }
        let accessibilityDescriptionWithoutGoal = String(
            localized: LocalizedStringResource(
                "planner.target.preview.accessibility.noGoal",
                defaultValue: "Monthly target: \(accessibleTotal).", locale: locale))

        return PlannerTargetPreview(
            goalSeconds: goalSeconds, scaleSeconds: scaleSeconds,
            monthlyBaseSeconds: monthlyBaseSeconds, adjustedBaseSeconds: adjustedBaseSeconds,
            bufferSeconds: bufferSeconds,
            totalSeconds: totalSeconds, solidFraction: solidFraction, extendedFraction: extendedFraction,
            markerFraction: markerFraction, accessibilityDescription: accessibilityDescription,
            accessibilityDescriptionWithoutGoal: accessibilityDescriptionWithoutGoal,
            baseLabel: baseLabel, adjustedLabel: adjustedLabel, bufferLabel: bufferLabel, totalLabel: totalText)
    }
}
