//
//  TrackerV13.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

extension SchemaV13 {
    @Model
    final class Tracker {
        var id: UUID = UUID()
        var name: String = ""
        var type: TrackerType = TrackerType.main

        var allowBibleStudies: Bool = true

        var isDefault: Bool = false

        var iconName: String = "tag.fill"
        /// The category color's hue, 0...1. Nil with `colorTone` means Automatic.
        /// Read and write through `categoryColor` / `setCategoryColor(_:)`.
        var colorHue: Double?
        /// The category color's tone, 0...1. See `CategoryColor`.
        var colorTone: Double?

        var createdAt: Date = Date()

        @Relationship(deleteRule: .nullify, inverse: \Entry.tracker)
        var entries: [Entry]? = []

        init(
            id: UUID = UUID(), name: String? = nil, type: TrackerType? = nil, allowBibleStudies: Bool? = nil,
            isDefault: Bool? = nil, iconName: String? = nil
        ) {
            self.id = id
            if let name = name { self.name = name } else { self.name = "" }

            if let type = type { self.type = type }

            if let allowBibleStudies = allowBibleStudies { self.allowBibleStudies = allowBibleStudies }

            if let isDefault = isDefault { self.isDefault = isDefault } else { self.isDefault = false }

            if let iconName = iconName { self.iconName = iconName }
        }
    }
}
