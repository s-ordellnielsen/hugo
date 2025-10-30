//
//  Enums.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 14/10/2025.
//

import Foundation

enum PublisherStatusGoalType {
    case yearly
    case monthly
    
    var label: LocalizedStringResource {
        switch self {
        case .yearly: return LocalizedStringResource("publisher.status.goaltype.yearly")
        case .monthly: return LocalizedStringResource("publisher.status.goaltype.monthly")
        }
    }
}
