//
//  Item.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
