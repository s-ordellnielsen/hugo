//
//  functions.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import Foundation

func formatDuration(_ totalSeconds: TimeInterval) -> String {
    let hours = Int(totalSeconds / 3600)
    let minutes = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
    
    return String(format: "%02d:%02d", hours, minutes)
}
