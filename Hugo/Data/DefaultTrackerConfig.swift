//
//  DefaultTrackerConfig.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 14/10/2025.
//

import Foundation

struct DefaultTrackerConfig {
    let id: UUID
    let localizationKey: LocalizedStringResource
    let iconName: String
    let hue: Double
}

extension DefaultTrackerConfig {
    static let defaults: [DefaultTrackerConfig] = [
        DefaultTrackerConfig(
            id: UUID(),
            localizationKey: "tracker.fieldservice.name",
            iconName: "figure.walk",
            hue: 0.5
        )
    ]
}
