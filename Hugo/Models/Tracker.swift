//
//  Tracker.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 14/10/2025.
//

import Foundation
import SwiftData

@Model
final class Tracker {
    var id: UUID = UUID()
    var name: String = ""
    var type: TrackerOutputType = TrackerOutputType.main
    
    @Transient var isDefault: Bool = false
    
    var iconName: String = "figure.walk"
    var hue: Double = 0.5
    
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \Entry.tracker)
    var entries: [Entry]? = []
    
    init(id: UUID = UUID(), name: String? = nil, type: TrackerOutputType? = nil, isDefault: Bool? = nil, iconName: String? = nil, hue: Double? = nil) {
        self.id = id
        if let name = name { self.name = name }
        else { self.name = "" }
        
        if let type = type { self.type = type }
        
        if let isDefault = isDefault { self.isDefault = isDefault }
        else { self.isDefault = false }
        
        if let iconName = iconName { self.iconName = iconName }
        if let hue = hue { self.hue = hue }
    }
}

enum TrackerOutputType: String, Codable, Comparable, Identifiable {
    case main
    case separate
    case none
    
    var id: String { self.rawValue }
    
    var label: String {
        switch self {
        case .main: return String(localized: "tracker.outputtype.main.label")
        case .separate: return String(localized: "tracker.outputtype.separate.label")
        case .none: return String(localized: "tracker.outputtype.none.label")
        }
    }
    
    var description: String {
        switch self {
        case .main: return String(localized: "tracker.outputtype.main.description")
        case .separate: return String(localized: "tracker.outputtype.separate.description")
        case .none: return String(localized: "tracker.outputtype.none.description")
        }
    }
    
    static func < (lhs: TrackerOutputType, rhs: TrackerOutputType) -> Bool {
        // Define a custom sorting order if needed
        // For example, you might want a specific order like this:
        let order: [TrackerOutputType] = [.main, .separate, .none]
        
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        
        return lhsIndex < rhsIndex
    }
}
