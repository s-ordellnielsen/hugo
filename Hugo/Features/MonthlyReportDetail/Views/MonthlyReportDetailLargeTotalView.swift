//
//  MonthlyReportDetailLargeTotalView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import SwiftUI

extension MonthlyReportDetailView {
    struct LargeTotal: View {
        let summary: MonthlySummary
        
        var primaryTotal: Int {
            summary.entries.reduce(0, { curr, acc in
                if acc.tracker?.type == .main {
                    return curr + acc.duration
                }
                
                return curr
            })
        }
        
        var secondaryTotal: Int {
            summary.entries.reduce(0, { curr, acc in
                if acc.tracker?.type == .separate {
                    return curr + acc.duration
                }
                
                return curr
            })
        }
        
        var body: some View {
            VStack {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDuration(primaryTotal))
                            .font(.callout)
                            .fontDesign(.monospaced)
                            .fontWeight(.medium)
                        Text("Field Service")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack {
                        Text(formatDuration(summary.totalSeconds))
                            .font(.largeTitle)
                            .fontDesign(.monospaced)
                            .fontWeight(.bold)
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDuration(secondaryTotal))
                            .font(.callout)
                            .fontDesign(.monospaced)
                            .fontWeight(.medium)
                        Text("Other")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(24)
        }
    }
}
