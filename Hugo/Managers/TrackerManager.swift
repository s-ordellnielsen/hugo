//
//  TrackerManager.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import Foundation
import SwiftData

class TrackerManager {
    private let context: ModelContext

    init(_ context: ModelContext) {
        self.context = context
    }
    
    func setAsDefault(_ tracker: Tracker) {
        let descriptor = FetchDescriptor<Tracker>(
            predicate: #Predicate { $0.isDefault == true }
        )
        
        if let currents = try? context.fetch(descriptor) {
            currents.forEach { t in
                t.isDefault = false
            }
        }
        
        tracker.isDefault = true
        
        try? context.save()
    }
}
