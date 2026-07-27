//
//  TrackerType.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//


import Foundation

enum TrackerType: String, Codable, Comparable, Identifiable, CaseIterable {
    case main
    case separate
    
    var id: String { self.rawValue }
    
    var label: String {
        switch self {
        case .main: return String(localized: "tracker.outputtype.main.label")
        case .separate: return String(localized: "tracker.outputtype.separate.label")
        }
    }
    
    var description: String {
        switch self {
        case .main: return String(localized: "tracker.outputtype.main.description")
        case .separate: return String(localized: "tracker.outputtype.separate.description")
        }
    }
    
    static func < (lhs: TrackerType, rhs: TrackerType) -> Bool {
        // Define a custom sorting order if needed
        // For example, you might want a specific order like this:
        let order: [TrackerType] = [.main, .separate]
        
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        
        return lhsIndex < rhsIndex
    }
}
