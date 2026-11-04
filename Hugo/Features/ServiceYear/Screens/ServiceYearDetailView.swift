import SwiftData
import SwiftUI

struct ServiceYearDetailView: View {
    let report: TheocraticYearReport
    /// Nil when the publisher status has no yearly goal.
    let progress: YearlyGoalProgress?

    var body: some View {
        List {
            if let progress {
                goalSection(progress)
            }
            totalsSection
            if let progress {
                monthsSection(progress)
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

    private func monthsSection(_ progress: YearlyGoalProgress) -> some View {
        Section {
            ForEach(progress.months.filter { !$0.isFuture }) { month in
                LabeledContent {
                    VStack(alignment: .trailing) {
                        duration(month.creditedSeconds)
                        if month.showsTotal {
                            Text(ServiceDurationFormatter.hoursString(from: month.totalSeconds))
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
        }
    }

    private func duration(_ seconds: TimeInterval) -> some View {
        Text(ServiceDurationFormatter.hoursString(from: seconds))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

#Preview {
    let report = ReportPreviewFixtures.yearReport
    let progress = PublisherStatus.status(for: "regular-pioneer").flatMap {
        YearlyGoalProgress.make(report: report, status: $0, pacing: .proRated)
    }
    NavigationStack {
        ServiceYearDetailView(report: report, progress: progress)
    }
    .modelContainer(.preview)
}
