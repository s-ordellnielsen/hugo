//
//  functions.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import Foundation

func formatDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    
    return String(format: "%02d:%02d", hours, minutes)
}
