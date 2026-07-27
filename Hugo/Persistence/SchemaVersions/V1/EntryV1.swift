//
//  EntryV1.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV1 {
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
}
