//
//  Item.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import Foundation
import SwiftData

@Model
final class Event {
    var type: EventType
    var timestamp: Date
    var duration: Int
    
    init(type: EventType, timestamp: Date, duration: Int) {
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
    }
}

enum EventType: String, Codable, CaseIterable, Identifiable {
    case fieldService
    case bethel
    case custom
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .fieldService: return "Field Service"
        case .bethel: return "Bethel"
        case .custom: return "Custom"
        }
    }
}
