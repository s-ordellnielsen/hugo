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

        var body: some View {
            VStack {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(height: 56)
                        .cornerRadius(24)
                        .overlay {
                            
                        }
                }
            }
        }
    }
}

#Preview {
    CurrentMonthProgressView<EmptyView>.DetailSheet()
}
