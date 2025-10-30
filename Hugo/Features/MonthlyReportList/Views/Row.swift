//
//  Row.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//

import SwiftData
import SwiftUI

extension MonthlyReportList {
    struct Row: View {
        var month: MonthlySummary

        @State private var showCopyAlert: Bool = false
        
        var fullHours: Int {
            month.totalSeconds / (60 * 60)
        }
        
        var leftoverMinutes: Int {
            (month.totalSeconds % 3600) / 60
        }

        var body: some View {
            Section(month.displayName) {
                HStack {
                    Text(formatDuration(month.totalSeconds))
                        .fontDesign(.monospaced)
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        showCopyAlert = true
                    } label: {
                        Label("Copy", systemImage: "square.on.square")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .alert("Report Limitations", isPresented: $showCopyAlert) {
                    Button {
                        UIPasteboard.general.string = "\(fullHours)"
                    } label: {
                        Label("Copy", systemImage: "square.on.square")
                            .labelStyle(.titleAndIcon)
                    }
                    Button(role: .cancel) {}
                } message: {
                    Text(
                        "You can only copy full hours, make sure to transfer \(leftoverMinutes) minutes to next month. Hugo will be able to do this for you in a future update"
                    )
                }
            }
        }

        private func formatDuration(_ totalSeconds: Int) -> String {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

#Preview {
    MonthlyReportList.Content()
        .modelContainer(.preview)
}
