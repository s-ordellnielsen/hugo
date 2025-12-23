//
//  TrackerSettingsOptionView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI

extension TrackerSettingsView {
    struct OptionView: View {
        @State var tracker: Tracker
        
        var body: some View {
            Form {
                Toggle("tracker.options.allow-bible-studies", isOn: $tracker.allowBibleStudies)
            }
        }
    }
}

#Preview {
    TrackerSettingsView.OptionView(tracker: Tracker(name: "Field Service"))
}
