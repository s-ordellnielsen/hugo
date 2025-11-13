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
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            Text("hours")
                                .foregroundStyle(.secondary)
                        }
                        .fontDesign(.monospaced)
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
                    .padding(.vertical, 8)
                }
                .labelReservedIconWidth(24)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(24)
            }
//            HStack {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text(formatDuration(month.totalSeconds))
//                        .fontDesign(.monospaced)
//                        .fontWeight(.semibold)
//                    HStack {
//                        Image(systemName: "book")
//                        Text("\(month.totalBibleStudies)")
//                    }
//                    .foregroundStyle(.secondary)
//                    .font(.callout)
//                    .fontWeight(.medium)
//                }
//                Spacer()
//                Button {
//                    showCopyAlert = true
//                } label: {
//                    Label("Copy", systemImage: "square.on.square")
//                        .labelStyle(.iconOnly)
//                        .foregroundStyle(.secondary)
//                }
//                .buttonStyle(.plain)
//            }
//            .padding()
//            .background(Color(.secondarySystemGroupedBackground))
//            .cornerRadius(24)
//            .alert("Report Limitations", isPresented: $showCopyAlert) {
//                Button {
//                    UIPasteboard.general.string = "\(fullHours)"
//                } label: {
//                    Label("Copy", systemImage: "square.on.square")
//                        .labelStyle(.titleAndIcon)
//                }
//                Button(role: .cancel) {}
//            } message: {
//                Text(
//                    "You can only copy full hours, make sure to transfer \(leftoverMinutes) minutes to next month. Hugo will be able to do this for you in a future update"
//                )
//            }
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}
