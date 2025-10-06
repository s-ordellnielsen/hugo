//
//  File.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

import Foundation
import Combine

enum EventSortOption: String, CaseIterable, Identifiable {
    case dateAscending = "Date (Ascending)"
    case dateDescending = "Date (Descending)"
    case category = "Category"
    
    var id: String { self.rawValue }
    
    func sort(events: [Event]) -> [Event] {
        switch self {
        case .dateAscending:
            return events.sorted(by: { $0.timestamp < $1.timestamp })
        case .dateDescending:
            return events.sorted(by: { $0.timestamp > $1.timestamp })
        case .category:
            return events.sorted(by: { $0.type.rawValue < $1.type.rawValue })
        }
    }
}

struct EventFilterCriteria: Equatable {
    var selectedType: EventType? = nil
    var selectedDateRange: ClosedRange<Date>? = nil
    
    var isActive: Bool {
        selectedType != nil || selectedDateRange != nil
    }
    
    func filter(events: [Event]) -> [Event] {
        events.filter { event in
            if let selectedType, event.type != selectedType {
                return false
            }
            
            if let selectedDateRange, !selectedDateRange.contains(event.timestamp) {
                return false
            }
            
            return true
        }
    }
    
    
    static let `default` = EventFilterCriteria()
}

final class EventListViewModel: ObservableObject {
    @Published var allEvents: [Event]
    @Published var sortOption: EventSortOption = .dateDescending
    @Published var filterCriteria: EventFilterCriteria = .default
    
    var events: [Event] {
        let filtered = filterCriteria.filter(events: allEvents)
        let sorted = sortOption.sort(events: filtered)
        return sorted
    }
    
    init(events: [Event]) {
        self.allEvents = events
    }
    
    func add(_ event: Event) {
        allEvents.append(event)
    }
    
    func update(_ event: Event) {
        if let index = allEvents.firstIndex(of: event) {
            allEvents[index] = event
        }
    }
    
    func delete(event: Event) {
        allEvents.removeAll(where: { $0.id == event.id })
    }
}
