//
//  TrackerV2_1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV8 {
    @Model
    final class Tracker {
        var id: UUID = UUID()
        var name: String = ""
        var type: TrackerType = TrackerType.main
        
        var allowBibleStudies: Bool = true
        
        var isDefault: Bool = false
        
        var iconName: String = "tag.fill"
        var hue: Double = 0.0
        var sat: Double = 1.0
        var bri: Double = 0.0
        
        var createdAt: Date = Date()
        
        @Relationship(deleteRule: .nullify, inverse: \Entry.tracker)
        var entries: [Entry]? = []
        
        init(id: UUID = UUID(), name: String? = nil, type: TrackerType? = nil, allowBibleStudies: Bool? = nil, isDefault: Bool? = nil, iconName: String? = nil, hue: Double? = nil, sat: Double? = nil, bri: Double? = nil) {
            self.id = id
            if let name = name { self.name = name }
            else { self.name = "" }
            
            if let type = type { self.type = type }
            
            if let allowBibleStudies = allowBibleStudies { self.allowBibleStudies = allowBibleStudies }
            
            if let isDefault = isDefault { self.isDefault = isDefault }
            else { self.isDefault = false }
            
            if let iconName = iconName { self.iconName = iconName }
            if let hue = hue { self.hue = hue }
            if let sat = sat { self.sat = sat }
            if let bri = bri { self.bri = bri }
        }
    }
}
