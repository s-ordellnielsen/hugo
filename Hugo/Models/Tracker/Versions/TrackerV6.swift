//
//  TrackerV2_1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV6 {
    @Model
    final class Tracker {
        var id: UUID = UUID()
        var name: String = ""
        var type: TrackerType = TrackerType.main
        
        var allowBibleStudies: Bool = true
        
        var isDefault: Bool = false
        
        var iconName: String = "figure.walk"
        var hue: Double = 0.5
        
        var createdAt: Date = Date()
        
        @Relationship(deleteRule: .nullify, inverse: \Entry.tracker)
        var entries: [Entry]? = []
        
        init(id: UUID = UUID(), name: String? = nil, type: TrackerType? = nil, isDefault: Bool? = nil, iconName: String? = nil, hue: Double? = nil) {
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
}
