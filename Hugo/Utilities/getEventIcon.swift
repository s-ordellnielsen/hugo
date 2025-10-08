//
//  getEventIcon.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

func getEventIcon(for eventType: EventType) -> String {
    switch eventType {
    case .fieldService:
        return "figure.walk"
    case .bethel:
        return "heart"
    case .custom:
        return "star"
    }
}
