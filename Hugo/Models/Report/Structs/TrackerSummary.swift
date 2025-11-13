//
//  TrackerSummary.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//

import Foundation
import SwiftData

struct TrackerSummary: Codable, Hashable {
    var name: String
    var duration: TimeInterval
    var type: TrackerType

    var hue: Double
    var sat: Double
    var bri: Double

    var icon: String?
}
