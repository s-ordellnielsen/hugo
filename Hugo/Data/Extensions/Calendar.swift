//
//  Calendar.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import Foundation

extension Calendar {
    func days(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []

        var current = start

        while current <= end {
            dates.append(current)
            guard let next = date(byAdding: .day, value: 1, to: current) else {
                break
            }
            current = next
        }
        
        return dates
    }
}
