//
//  TrackerSettingsDetailsEntryList.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI
import SwiftData

extension TrackerSettingsView {
    struct DetailsEntryList: View {
        var tracker: Tracker
        
        @Query private var entries: [Entry]
        
        var body: some View {
            VStack {
                
            }
        }
    }
}
    
#Preview {
    TrackerSettingsView.DetailsEntryList(tracker: .init(name: "Test"))
}
