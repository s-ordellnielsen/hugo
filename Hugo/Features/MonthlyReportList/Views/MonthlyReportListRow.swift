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
                        Button {
                        } label: {
                            Label("Show details", systemImage: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .labelStyle(.iconOnly)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    HStack {
                        HStack(alignment: .firstTextBaseline) {
                            Text(formatDuration(month.totalSeconds))
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 4)
                            Text("hours")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                        }
                        .fontDesign(.rounded)
                    }
                    Divider()
                    VStack {
                        ForEach(month.trackers) { t in
                            HStack {
                                Label(t.tracker.name, systemImage: t.tracker.iconName)
                                Spacer()
                                Text(formatDuration(t.total))
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                    }
                    .padding(.vertical, 8)
                    Divider()
                    VStack {
                        HStack {
                            Label("Bible Studies", systemImage: "book")
                            Spacer()
                            Text("\(month.totalBibleStudies)")
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    .padding(.top, 8)
                }
                .labelReservedIconWidth(24)
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
