//
//  DailyPoint.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/11/2025.
//


import Foundation
import SwiftData

struct DailyPoint: Codable, Hashable, Identifiable {
    var date: Date
    var total: TimeInterval
    
    var id: Date { date }
}
