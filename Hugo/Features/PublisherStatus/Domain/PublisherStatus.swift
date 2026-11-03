import Foundation

nonisolated enum PublisherGoalPeriod {
    case yearly
    case monthly

    var label: LocalizedStringResource {
        switch self {
        case .yearly: "publisher.status.goaltype.yearly"
        case .monthly: "publisher.status.goaltype.monthly"
        }
    }
}

nonisolated struct PublisherStatus: Identifiable {
    let id: String
    let nameKey: LocalizedStringResource
    let shortName: LocalizedStringResource
    let goalPeriod: PublisherGoalPeriod
    let goal: Int
    /// Hours of separate-category time that may count on top of the monthly goal.
    var separateAllowanceHours: Int = 0

    var monthlyGoal: Int {
        goalPeriod == .yearly ? goal / 12 : goal
    }

    var yearlyGoal: Int {
        goalPeriod == .monthly ? goal * 12 : goal
    }

    /// The credit rule for statuses that count hours toward a yearly goal; nil otherwise.
    var yearlyGoalRule: YearlyGoalRule? {
        guard goalPeriod == .yearly, goal > 0 else { return nil }
        return YearlyGoalRule(
            monthlyGoalSeconds: TimeInterval(monthlyGoal) * 3_600,
            separateAllowanceSeconds: TimeInterval(separateAllowanceHours) * 3_600)
    }

    var goalDescription: LocalizedStringResource {
        guard goal > 0 else {
            return "publisher.status.goal.description.none"
        }

        switch goalPeriod {
        case .monthly:
            return LocalizedStringResource(
                "publisher.status.goal.description.monthly", defaultValue: "\(goal) hours per month",
                comment: "A publisher status goal expressed as a number of hours per month.")
        case .yearly:
            return LocalizedStringResource(
                "publisher.status.goal.description.yearly", defaultValue: "\(goal) hours per year",
                comment: "A publisher status goal expressed as a number of hours per year.")
        }
    }

    static let all: [PublisherStatus] = [
        PublisherStatus(
            id: "regular-pioneer", nameKey: "publisher.status.regularpioneer.full",
            shortName: "publisher.status.regularpioneer.short", goalPeriod: .yearly, goal: 600,
            separateAllowanceHours: 5),
        PublisherStatus(
            id: "auxiliary-pioneer", nameKey: "publisher.status.auxiliary.full",
            shortName: "publisher.status.auxiliary.short", goalPeriod: .monthly, goal: 30),
        PublisherStatus(
            id: "publisher", nameKey: "publisher.status.publisher.full", shortName: "publisher.status.publisher.short",
            goalPeriod: .monthly, goal: 0),
    ]

    static func status(for identifier: String) -> PublisherStatus? {
        all.first { $0.id == identifier }
    }
}
