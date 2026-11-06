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
    let monthlyBaseDescription: String
    let adjustedDescription: String
    let accessibilityDescription: String
    let accessibilityDescriptionWithoutGoal: String
    let goalLabel: String
    let baseLabel: String
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
        let currentYear = TheocraticYear.containing(now, calendar: calendar)
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
        let goalText = goalSeconds.map { ServiceDurationFormatter.hoursString(from: $0, locale: locale) } ?? ""
        let baseText = ServiceDurationFormatter.hoursString(from: selectedBaseSeconds, locale: locale)
        let bufferText = ServiceDurationFormatter.hoursString(from: bufferSeconds, locale: locale)
        let goalLabel = String(
            localized: LocalizedStringResource(
                "planner.target.preview.goal", defaultValue: "Monthly goal: \(goalText)", locale: locale))
        let baseLabel = String(
            localized: LocalizedStringResource(
                "planner.target.preview.base", defaultValue: "Base target: \(baseText)", locale: locale))
        let bufferLabel = String(
            localized: LocalizedStringResource(
                "planner.target.preview.buffer", defaultValue: "Buffer: \(bufferText)", locale: locale))
        let monthlyBaseDescription = String(
            localized: LocalizedStringResource(
                "planner.target.base.monthlyGoal.description",
                defaultValue: "Uses the monthly goal for your publisher status.", locale: locale))
        let remainingSeconds = max(0, TimeInterval(status?.yearlyGoal ?? 0) * 3_600 - creditedBeforeCurrentMonth)
        let remainingMonths = currentYear.months.filter { $0 >= month }.count
        let remainingDuration = ServiceDurationFormatter.hoursString(from: remainingSeconds, locale: locale)
        let monthCount = remainingMonths.formatted(.number.locale(locale))
        let adjustedDescription = String(
            localized: LocalizedStringResource(
                "planner.target.base.yearlyGoalShare.description",
                defaultValue: "Remaining yearly goal: \(remainingDuration). Months remaining: \(monthCount).",
                locale: locale))
        let accessibleGoal = ServiceDurationFormatter.accessibilityString(from: goalSeconds ?? 0, locale: locale)
        let accessibleBase = ServiceDurationFormatter.accessibilityString(from: selectedBaseSeconds, locale: locale)
        let accessibleBuffer = ServiceDurationFormatter.accessibilityString(from: bufferSeconds, locale: locale)
        let accessibleTotal =
            totalSeconds.map { ServiceDurationFormatter.accessibilityString(from: $0, locale: locale) }
            ?? String(localized: LocalizedStringResource("planner.target.none", locale: locale))
        let selectedBaseLabel = String(
            localized: LocalizedStringResource(
                base == .monthlyGoal ? "planner.target.base.monthlyGoal" : "planner.target.base.yearlyGoalShare",
                locale: locale))
        let accessibilityDescription = String(
            localized: LocalizedStringResource(
                "planner.target.preview.accessibility",
                defaultValue:
                    "Monthly goal: \(accessibleGoal). \(selectedBaseLabel): \(accessibleBase). Buffer: \(accessibleBuffer). Target: \(accessibleTotal).",
                locale: locale))
        let accessibilityDescriptionWithoutGoal = String(
            localized: LocalizedStringResource(
                "planner.target.preview.accessibility.noGoal",
                defaultValue: "Monthly target: \(accessibleTotal).", locale: locale))

        return PlannerTargetPreview(
            goalSeconds: goalSeconds, scaleSeconds: scaleSeconds,
            monthlyBaseSeconds: monthlyBaseSeconds, adjustedBaseSeconds: adjustedBaseSeconds,
            bufferSeconds: bufferSeconds,
            totalSeconds: totalSeconds, solidFraction: solidFraction, extendedFraction: extendedFraction,
            markerFraction: markerFraction, monthlyBaseDescription: monthlyBaseDescription,
            adjustedDescription: adjustedDescription, accessibilityDescription: accessibilityDescription,
            accessibilityDescriptionWithoutGoal: accessibilityDescriptionWithoutGoal,
            goalLabel: goalLabel, baseLabel: baseLabel, bufferLabel: bufferLabel, totalLabel: totalText)
    }
}
