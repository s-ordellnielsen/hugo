import Foundation
import Testing

@testable import Hugo

@MainActor
struct ReportAdjustmentsTests {
    private func line(
        _ name: String = "",
        type: TrackerType = .main,
        seconds: TimeInterval,
        hours: Int,
        rounding: String? = nil
    ) -> SubmittedReport.SubmittedReportingLine {
        SubmittedReport.SubmittedReportingLine(
            typeRaw: type.rawValue,
            typeName: name,
            durationInSeconds: seconds,
            submittedHours: hours,
            roundingRaw: rounding
        )
    }

    @Test
    func roundUp() {
        let adjustments = ReportAdjustments(lines: [line(seconds: 38_400, hours: 11, rounding: "up")])
        #expect(adjustments.roundedUpSeconds == 1_200)
        #expect(adjustments.roundedDownSeconds == 0)
        #expect(adjustments.transferredSeconds == 0)
    }

    @Test
    func roundDown() {
        let adjustments = ReportAdjustments(lines: [line(seconds: 38_400, hours: 10, rounding: "down")])
        #expect(adjustments.roundedDownSeconds == 2_400)
        #expect(adjustments.roundedUpSeconds == 0)
        #expect(adjustments.transferredSeconds == 0)
    }

    @Test
    func transfer() {
        let adjustments = ReportAdjustments(lines: [line(seconds: 38_400, hours: 10, rounding: "transfer")])
        #expect(adjustments.transferredSeconds == 2_400)
        #expect(adjustments.roundedDownSeconds == 0)
    }

    @Test
    func wholeHourLineWithTheDefaultRuleAddsNothing() {
        let adjustments = ReportAdjustments(lines: [line(seconds: 3_600, hours: 1)])
        #expect(adjustments.isEmpty)
    }

    @Test
    func lineWithoutARuleAddsNothing() {
        let adjustments = ReportAdjustments(lines: [line(seconds: 3_600, hours: 1, rounding: "")])
        #expect(adjustments.isEmpty)
    }

    @Test
    func sumsAcrossLines() {
        let adjustments = ReportAdjustments(lines: [
            line(seconds: 38_400, hours: 11, rounding: "up"),
            line("Bethel", type: .separate, seconds: 10_200, hours: 3, rounding: "up"),
            line("LDC", type: .separate, seconds: 4_500, hours: 1, rounding: "transfer"),
        ])
        #expect(adjustments.roundedUpSeconds == 1_800)
        #expect(adjustments.transferredSeconds == 900)
        #expect(adjustments.roundedDownSeconds == 0)
    }

    @Test
    func noLines() {
        #expect(ReportAdjustments(lines: []).isEmpty)
    }
}
