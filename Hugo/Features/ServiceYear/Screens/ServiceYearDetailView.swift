import SwiftData
import SwiftUI

struct ServiceYearDetailView: View {
    let report: TheocraticYearReport
    /// Nil when the publisher status has no yearly goal.
    let progress: YearlyGoalProgress?
    let status: PublisherStatus?

    var body: some View {
        List {
            if let progress {
                goalSection(progress)
            }
            totalsSection
            if let progress, let status {
                monthsSection(progress, status)
            }
        }
        .navigationTitle(report.year.displayName)
        .navigationSubtitle("year.detail.subtitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EditorialNavigationTitle(title: report.year.displayName)
            }
        }
    }

    private func goalSection(_ progress: YearlyGoalProgress) -> some View {
        Section("year.detail.section.goal") {
            LabeledContent("year.detail.credited") {
                duration(progress.creditedSeconds)
            }
            LabeledContent("year.detail.goal") {
                duration(progress.yearlyGoalSeconds)
            }
            if let expected = progress.expectedSeconds {
                LabeledContent("year.detail.expected") {
                    duration(expected)
                }
            }
            if let sentence = progress.paceSentence {
                LabeledContent("year.detail.difference") {
                    Text(sentence).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var totalsSection: some View {
        Section("year.detail.section.totals") {
            LabeledContent("monthlyReport.detail.largeTotal.main.label") {
                duration(report.mainDuration)
            }
            LabeledContent("monthlyReport.detail.largeTotal.separate.label") {
                duration(report.separateDuration)
            }
            LabeledContent("monthlyReport.detail.largeTotal.total.label") {
                duration(report.totalSeconds)
            }
            LabeledContent("report.bible-studies") {
                Text(report.totalBibleStudies, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func monthsSection(_ progress: YearlyGoalProgress, _ status: PublisherStatus) -> some View {
        Section {
            ForEach(report.months.filter { !$0.isFuture }) { month in
                let credited = progress.creditedByMonth[month.id] ?? 0
                let actual = TheocraticYearReportBuilder.contribution(for: month).total
                LabeledContent {
                    VStack(alignment: .trailing) {
                        duration(credited)
                        if abs(actual - credited) >= 60 {
                            Text(ServiceDurationFormatter.string(from: actual))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                    }
                } label: {
                    Text(month.displayName)
                }
            }
        } header: {
            Text("year.detail.section.months")
        } footer: {
            Text(
                String(
                    localized: "year.detail.credit.footer",
                    defaultValue:
                        "Main field service always counts toward your yearly goal. Time in other categories counts only until you reach your monthly goal plus \(status.separateAllowanceHours) hours.",
                    comment:
                        "Explains which hours count toward the yearly goal. The argument is the number of extra hours of other categories that may count on top of the monthly goal."
                ))
        }
    }

    private func duration(_ seconds: TimeInterval) -> some View {
        Text(ServiceDurationFormatter.string(from: seconds))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

#Preview {
    let status = PublisherStatus.status(for: "regular-pioneer")
    let report = ReportPreviewFixtures.yearReport
    let progress = status?.yearlyGoalRule.map {
        YearlyGoalProgress.make(
            report: report, rule: $0, yearlyGoalSeconds: 600 * 3_600, pacing: .proRated)
    }
    NavigationStack {
        ServiceYearDetailView(report: report, progress: progress, status: status)
    }
    .modelContainer(.preview)
}
