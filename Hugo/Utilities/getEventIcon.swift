//
//  getEventIcon.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

func getEventIcon(for eventType: EventType) -> String {
    switch eventType {
    case .fieldService:
        return "briefcase.fill"
    case .bethel:
        return "building.2.crop.circle"
    case .custom:
        return "star"
    }
}
