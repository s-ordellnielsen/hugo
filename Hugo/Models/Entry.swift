//
//  Item.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import Foundation
import SwiftData

@Model
final class Entry {
    var type: EventType = EventType.fieldService
    var timestamp: Date = Date()
    var duration: Int = 0
    
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
            Entry(type: .fieldService, timestamp: Date(), duration: 3600),
            Entry(type: .bethel, timestamp: Date().addingTimeInterval(-86_400), duration: 3600),
            Entry(type: .custom, timestamp: Date().addingTimeInterval(-1_728_000), duration: 3600),
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

