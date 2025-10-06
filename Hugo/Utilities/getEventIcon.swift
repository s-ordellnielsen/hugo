//
//  getEventIcon.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

func getEventIcon(for event: Event) -> String {
    switch event.type {
    case .fieldService:
        return "briefcase.fill"
    case .bethel:
        return "building.2.crop.circle"
    case .custom:
        return "pencil.and.paper"
    }
}
