import Foundation
import Testing

@testable import Hugo

@MainActor
struct ReportedTextTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US")
    private let month = YearMonth(year: 2026, month: 11)
    private let sent = Date(timeIntervalSince1970: 1_796_000_000)

    @Test
    func listsSentLinesWithFieldServiceFirst() {
        let report = makeReport(
            lines: [line(.separate, name: "LDC", hours: 5), line(.main, hours: 52)], studies: 4)

        #expect(
            text(report) == "November 2026\nField Service: 52 h\nLDC: 5 h\nBible studies: 4")
    }

    @Test
    func addsSchoolCreditAsOneLine() {
        let report = makeReport(lines: [line(.main, hours: 40)], studies: 0)
        report.schoolCreditHours = 30

        #expect(
            text(report) == "November 2026\nField Service: 40 h\nSchool credit: 30 h\nBible studies: 0")
    }

    @Test
    func olderReportWithoutLinesUsesTheTotal() {
        let report = makeReport(lines: [], studies: 2)
        report.submittedHours = 38

        #expect(text(report) == "November 2026\nField Service: 38 h\nBible studies: 2")
    }

    @Test
    func placeholderReportHasNoText() {
        let report = SubmittedReport(year: 2026, month: 11)
        #expect(text(report) == nil)
    }

    private func text(_ report: SubmittedReport) -> String? {
        ReportComposer.reportedText(for: report, month: month, locale: locale, calendar: calendar)
    }

    private func makeReport(lines: [SubmittedReport.SubmittedReportingLine], studies: Int) -> SubmittedReport {
        SubmittedReport(
            year: 2026, month: 11, firstSubmittedAt: sent, submittedAt: sent, totalBibleStudies: studies,
            reportingLines: lines)
    }

    private func line(_ type: TrackerType, name: String = "", hours: Int) -> SubmittedReport.SubmittedReportingLine {
        SubmittedReport.SubmittedReportingLine(
            typeRaw: type.rawValue, typeName: name, durationInSeconds: 0, submittedHours: hours)
    }
}
