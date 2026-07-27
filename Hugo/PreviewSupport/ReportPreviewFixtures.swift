import Foundation

@MainActor
enum ReportPreviewFixtures {
    static let entries: [Entry] = {
        let main = Tracker(name: "Field Service", type: .main, isDefault: true, iconName: "figure.walk")
        let separate = Tracker(name: "Bethel", type: .separate, iconName: "building")
        return [
            Entry(date: Date(), duration: 3_600, tracker: main, bibleStudies: 1),
            Entry(date: Date(), duration: 7_200, tracker: separate),
        ]
    }()

    static var summary: MonthlyReportSummary {
        MonthlyReportBuilder.summaries(from: entries).first!
    }

    static var currentYear: TheocraticYear { Date().theocraticYear() }

    static var yearReport: TheocraticYearReport {
        TheocraticYearReportBuilder.report(for: currentYear, entries: entries)
    }

    static var emptyMonth: TheocraticYearMonth {
        yearReport.months.first { $0.summary == nil } ?? yearReport.months[0]
    }
}
