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
    
    public func delete(in context: ModelContext) {
        context.delete(self)
    }
    
    static func makeSampleData(in container: ModelContainer) {
        let context = ModelContext(container)
        let data = [
            Event(type: .fieldService, timestamp: Date(), duration: 3600),
            Event(type: .bethel, timestamp: Date().addingTimeInterval(-86_400), duration: 3600),
            Event(type: .custom, timestamp: Date().addingTimeInterval(-1_728_000), duration: 3600),
        ]
        for event in data {
            context.insert(event)
        }
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

