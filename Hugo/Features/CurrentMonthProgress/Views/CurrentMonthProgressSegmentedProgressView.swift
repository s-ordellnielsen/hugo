//
//  CurrentMonthProgressSegmentedProgressView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftData
import SwiftUI

extension CurrentMonthProgressView {
    struct SegmentedProgressView: View {
        static var currentMonthPredicate: Predicate<Entry> {
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth =
                calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth =
                calendar.date(byAdding: .month, value: 1, to: startOfMonth)
                ?? now

            return #Predicate<Entry> { entry in
                entry.date >= startOfMonth && entry.date < endOfMonth
            }
        }

        @Query(filter: OverviewView.currentMonthPredicate) private var entries:
            [Entry]
        @Query private var trackers: [Tracker]
        
        @AppStorage(UserDefaults.publisherStatusKey) private var publisherStatus: String = ""
        
        var max: Double {
            guard let goal = PublisherStatusConfig.current(publisherStatus)?.monthlyGoal() else { return 0 }
            
            let total = entries.reduce(0) { $0 + $1.duration } / 3600
            
            return Swift.max(Double(goal), total)
        }
        
        var colors: [Color] {
            let maxHue: Double = 0.2
            let steps = maxHue / Double(trackers.count)
            guard steps > 0 else { return [] }
            
            return stride(from: 0, through: maxHue, by: steps).map {
                Color(hue: $0, saturation: 0.75, brightness: 1)
            }
        }

        var body: some View {
            if max != 0 {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(trackers.enumerated(), id: \.offset) { index, tracker in
                                let filtered = entries.filter { entry in
                                    entry.tracker == tracker
                                }
                                let total = filtered.reduce(0) {
                                    $0 + $1.duration
                                }
                                let normalized = CGFloat(total) / (CGFloat(self.max) * 3600)
                                let width = geometry.size.width * normalized
                                
                                print("Tracker \(tracker.name) total: \(total), normalized: \(normalized)")
                                
                                return Rectangle()
                                    .fill(colors[index])
                                    .frame(width: width)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(24)
                    }
                    .frame(height: 56)
                    VStack(spacing: 12) {
                        ForEach(trackers.enumerated(), id: \.offset) { index, tracker in
                            let filtered = entries.filter { entry in
                                entry.tracker == tracker
                            }
                            let total = filtered.reduce(0) {
                                $0 + $1.duration
                            }
                            
                            return HStack(spacing: 16) {
                                Image(systemName: tracker.iconName)
                                    .foregroundStyle(colors[index])
                                    .frame(width: 12, height: 12)
                                Text(tracker.name)
                                Spacer()
                                Text(formatDuration(total))
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                            }
                            .labelReservedIconWidth(32)
                            .font(.callout)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    CurrentMonthProgressView<EmptyView>.DetailSheet()
        .modelContainer(.preview)
}
