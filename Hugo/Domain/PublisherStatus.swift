import Foundation

enum PublisherGoalPeriod {
    case yearly
    case monthly

    var label: LocalizedStringResource {
        switch self {
        case .yearly: "publisher.status.goaltype.yearly"
        case .monthly: "publisher.status.goaltype.monthly"
        }
    }
}

struct PublisherStatus: Identifiable {
    let id: String
    let nameKey: LocalizedStringResource
    let shortName: LocalizedStringResource
    let goalPeriod: PublisherGoalPeriod
    let goal: Int

    var monthlyGoal: Int {
        goalPeriod == .yearly ? goal / 12 : goal
    }

    var yearlyGoal: Int {
        goalPeriod == .monthly ? goal * 12 : goal
    }

    static let all: [PublisherStatus] = [
        PublisherStatus(id: "regular-pioneer", nameKey: "publisher.status.regularpioneer.full", shortName: "publisher.status.regularpioneer.short", goalPeriod: .yearly, goal: 600),
        PublisherStatus(id: "auxiliary-pioneer", nameKey: "publisher.status.auxiliary.full", shortName: "publisher.status.auxiliary.short", goalPeriod: .monthly, goal: 30),
        PublisherStatus(id: "publisher", nameKey: "publisher.status.publisher.full", shortName: "publisher.status.publisher.short", goalPeriod: .monthly, goal: 0),
    ]

    static func status(for identifier: String) -> PublisherStatus? {
        all.first { $0.id == identifier }
    }
}
