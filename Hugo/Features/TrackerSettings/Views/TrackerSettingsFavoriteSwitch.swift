//
//  TrackerSettingsFavoriteSwitch.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI

extension TrackerSettingsView {
    struct FavoriteSwitch: View {
        @Environment(\.modelContext) private var context
        
        @State var tracker: Tracker

        var body: some View {
            Button {
                if tracker.isDefault {
                    tracker.isDefault = false
                } else {
                    let manager = TrackerManager(context)
                    manager.setAsDefault(tracker)
                }
//                tracker.isDefault.toggle()
            } label: {
                Image(systemName: tracker.isDefault ? "star.fill" : "star")
                    .foregroundStyle(tracker.isDefault ? .yellow : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrackerSettingsView.DetailView(tracker: Tracker(name: "Field Service"))
    }
}
