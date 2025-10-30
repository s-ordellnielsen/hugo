//
//  PublisherStatusConfig.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/10/2025.
//

import Foundation

struct PublisherStatusConfig: Identifiable {
    let id: String
    var nameKey: LocalizedStringResource
    var shortName: LocalizedStringResource
    var goalType: PublisherStatusGoalType
    var goal: Int

    public func monthlyGoal() -> Int {
        if goalType == .yearly {
            return goal / 12
        }

        return goal
    }

    public func yearlyGoal() -> Int {
        if goalType == .monthly {
            return goal * 12
        }

        return goal
    }
}

extension PublisherStatusConfig {
    static let defaults: [PublisherStatusConfig] = [
        PublisherStatusConfig(
            id: "regular-pioneer",
            nameKey: "publisher.status.regularpioneer.full",
            shortName: "publisher.status.regularpioneer.short",
            goalType: .yearly,
            goal: 600
        ),
        PublisherStatusConfig(
            id: "auxiliary-pioneer",
            nameKey: "publisher.status.auxiliary.full",
            shortName: "publisher.status.auxiliary.short",
            goalType: .monthly,
            goal: 30
        ),
    ]
    
    static func current(_ currentStatusId: String) -> PublisherStatusConfig? {        
        if currentStatusId != "" {
            let currentStatus = PublisherStatusConfig.defaults.first(where: { $0.id == currentStatusId })
            
            if currentStatus != nil {
                return currentStatus
            }
        }
        
        return nil
    }
}
