//
//  SavedReportListItemView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 13/11/2025.
//

import Charts
import SwiftUI

extension SavedReportListView {
    struct ListItem: View {
        let report: Report

        var formattedMonth: String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM, yyyy"

            var dateComponents = DateComponents()
            dateComponents.year = report.year
            dateComponents.month = report.month

            if let date = Calendar.current.date(from: dateComponents) {
                return dateFormatter.string(from: date)
            }

            return dateFormatter.string(from: Date())
        }

        private func dailyPoints() -> [DailyPoint] {
            let calendar = Calendar.current

            var comps = DateComponents()
            comps.year = report.year
            comps.month = report.month
            comps.day = 1

            guard let monthStart = calendar.date(from: comps) else { return [] }
            guard
                let monthRange = calendar.range(
                    of: .day,
                    in: .month,
                    for: monthStart
                )
            else { return [] }
            let monthEndDay = monthRange.count

            comps.day = monthEndDay
            guard let monthEnd = calendar.date(from: comps) else { return [] }

            let normalizedInput: [Date: DailyPoint] = Dictionary(
                uniqueKeysWithValues:
                    report.dailyPoints.map {
                        (calendar.startOfDay(for: $0.date), $0)
                    }
            )

            let allDates = calendar.days(
                from: calendar.startOfDay(for: monthStart),
                to: calendar.startOfDay(for: monthEnd)
            )
            return allDates.map { d in
                if let existing = normalizedInput[d] {
                    return existing
                } else {
                    // If you prefer "carry forward last value as an explicit point" instead of zero
                    // you can set hours to 0 here and cumulative algorithm will carry previous sum.
                    return DailyPoint(date: d, total: 0)
                }
            }
        }

        private var cumulativePoints: [CumulativePoint] {
            var running: Double = 0
            var result: [CumulativePoint] = []

            for point in dailyPoints() {
                running += (point.total / 3600)
                result.append(.init(date: point.date, cumulativeHours: running))
            }

            return result
        }

        var body: some View {
            NavigationLink(destination: Text("Report")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(formattedMonth)
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
                            Text(formatDuration(report.fieldService))
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 4)
                            Text("hours")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                        }
                        .fontDesign(.rounded)
                    }
                    //                    Divider()
                    //                    VStack {
                    //                        ForEach(month.trackers) { t in
                    //                            HStack {
                    //                                Label(t.tracker.name, systemImage: t.tracker.iconName)
                    //                                Spacer()
                    //                                Text(formatDuration(t.total))
                    //                                    .fontDesign(.monospaced)
                    //                                    .foregroundStyle(.secondary)
                    //                            }
                    //                        }
                    //                        .font(.callout)
                    //                    }
                    //                    .padding(.vertical, 8)
                    Divider()
                    VStack {
                        HStack {
                            Label("Bible Studies", systemImage: "book")
                            Spacer()
                            Text("\(report.bibleStudies)")
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    .padding(.vertical, 8)
                    if !report.dailyPoints.isEmpty {
                        Divider()
                        Chart {
                            ForEach(cumulativePoints) { p in
                                AreaMark(
                                    x: .value("Date", p.date),
                                    y: .value("Minutes", p.cumulativeHours)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Gradient(colors: [.blue.opacity(0.25), .blue.opacity(0)]))
                            }
                            ForEach(cumulativePoints) { p in
                                LineMark(
                                    x: .value("Date", p.date),
                                    y: .value("Minutes", p.cumulativeHours)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.blue)
                            }
                            if report.goal != 0 {
                                RuleMark(
                                    y: .value("Goal", report.goal)
                                )
                                .foregroundStyle(.blue.opacity(0.15))
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                    }
                }
                .labelReservedIconWidth(24)
                .padding(24)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(32)
            }
            .onAppear {
                print(report.dailyPoints)
                print(report.trackers)
            }

        }
    }
}

private struct CumulativePoint: Identifiable {
    let id = UUID()
    let date: Date
    let cumulativeHours: Double
}

#Preview {
    @Previewable @Environment(\.modelContext) var context

    let reports = sampleReports()

    NavigationStack {
        ScrollView {
            SavedReportListView(reports: reports)
                .navigationTitle("Reports")
                .navigationBarTitleDisplayMode(.inline)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
