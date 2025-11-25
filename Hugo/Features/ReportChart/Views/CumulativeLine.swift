//
//  CumulativeLine.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 15/11/2025.
//

import SwiftUI
import Charts

extension ReportChart {
    struct CumulativeLine: View {
        var report: Report
        
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
            Chart {
                ForEach(cumulativePoints) { p in
                    AreaMark(
                        x: .value("common.date", p.date),
                        y: .value("common.minutes", p.cumulativeHours)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Gradient(colors: [.accent.opacity(0.25), .accent.opacity(0)]))
                }
                ForEach(cumulativePoints) { p in
                    LineMark(
                        x: .value("common.date", p.date),
                        y: .value("common.minutes", p.cumulativeHours)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.accent)
                }
                if report.goal != 0 {
                    RuleMark(
                        y: .value("goal.label", report.goal)
                    )
                    .foregroundStyle(.accent.opacity(0.15))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}

private struct CumulativePoint: Identifiable {
    let id = UUID()
    let date: Date
    let cumulativeHours: Double
}

#Preview {
    let reports = sampleReports()
    let report = reports.first!
    
    ReportChart.CumulativeLine(report: report)
}
