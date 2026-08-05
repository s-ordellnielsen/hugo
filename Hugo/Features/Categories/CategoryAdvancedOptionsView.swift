//
//  TrackerSettingsOptionView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI

struct CategoryAdvancedOptionsView: View {
    var tracker: Tracker

    var body: some View {
        @Bindable var tracker = tracker
        Form {
            Toggle("tracker.options.allow-bible-studies", isOn: $tracker.allowBibleStudies)
        }
    }
}

#Preview {
    CategoryAdvancedOptionsView(tracker: Tracker(name: "Field Service"))
}
