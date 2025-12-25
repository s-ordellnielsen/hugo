//
//  Row.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//

import SwiftData
import SwiftUI

extension MonthlyReportListView {
    struct Row: View {
        var month: MonthlySummary

        @State private var showCopyAlert: Bool = false

        var fullHours: TimeInterval {
            month.totalSeconds / (60 * 60)
        }

        var leftoverMinutes: TimeInterval {
            month.totalSeconds.truncatingRemainder(dividingBy: 3600) / 60
        }
        
        var trackers: [MonthlySummaryTracker] {
            month.trackers.sorted { $0.total > $1.total }
        }

        var body: some View {
            NavigationLink(destination: MonthlyReportDetailView(summary: month)) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(month.displayName)
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatDuration(month.totalSeconds))
                                .font(.title)
                                .fontWeight(.heavy)
                                .padding(.top, 2)
                            Text("reportList.row.hours.label")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                                .font(.title3)
                        }
                        .fontDesign(.rounded)
                    }
                    Divider()
                    VStack(spacing: 12) {
                        ForEach(trackers) { t in
                            HStack {
                                Label(t.tracker.name, systemImage: t.tracker.iconName)
                                Spacer()
                                Text(formatDuration(t.total))
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                        Divider()
                            .padding(.vertical, 8)
                        VStack {
                            HStack {
                                Label("report.bible-studies", systemImage: "book")
                                Spacer()
                                Text(String("\(month.totalBibleStudies)"))
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                    .padding(.top, 12)
                    .labelReservedIconWidth(24)
                }
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(32)
                .tint(.primary)
            }
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}
