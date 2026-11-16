import Foundation
import Testing

@testable import Hugo

struct SchoolCreditLineTests {
    private let october = YearMonth(year: 2026, month: 10)
    private let november = YearMonth(year: 2026, month: 11)

    @Test
    func sumsCreditsOfTheSameSchoolInTheMonth() {
        let credits = [
            SchoolCredit(schoolID: "pioneer-service-school", month: october, hours: 15),
            SchoolCredit(schoolID: "pioneer-service-school", month: october, hours: 10),
        ]

        let lines = SchoolCreditLine.lines(from: credits, in: october)

        #expect(lines == [SchoolCreditLine(schoolID: "pioneer-service-school", hours: 25)])
    }

    @Test
    func ignoresOtherMonths() {
        let credits = [
            SchoolCredit(schoolID: "pioneer-service-school", month: october, hours: 10),
            SchoolCredit(schoolID: "pioneer-service-school", month: november, hours: 30),
        ]

        let lines = SchoolCreditLine.lines(from: credits, in: october)

        #expect(lines == [SchoolCreditLine(schoolID: "pioneer-service-school", hours: 10)])
    }

    @Test
    func knownSchoolsComeBeforeUnknownOnes() {
        let credits = [
            SchoolCredit(schoolID: "zzz-school", month: october, hours: 5),
            SchoolCredit(schoolID: "pioneer-service-school", month: october, hours: 10),
        ]

        let lines = SchoolCreditLine.lines(from: credits, in: october)

        #expect(lines.map(\.schoolID) == ["pioneer-service-school", "zzz-school"])
    }
}
