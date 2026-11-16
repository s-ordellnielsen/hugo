import Foundation

/// One school's credit hours in one month, as a report shows them.
nonisolated struct SchoolCreditLine: Identifiable, Equatable, Sendable {
    let schoolID: String
    let hours: Int

    var id: String { schoolID }

    /// The school credits of `month`, one line per school with its hours
    /// summed. Known schools come first in `School.allCases` order; schools
    /// this build doesn't know follow, sorted by id.
    static func lines(from credits: [SchoolCredit], in month: YearMonth) -> [SchoolCreditLine] {
        var hoursBySchool: [String: Int] = [:]
        for credit in credits where credit.yearMonth == month {
            hoursBySchool[credit.schoolID, default: 0] += credit.hours
        }
        let known = School.allCases.map(\.rawValue)
        return
            hoursBySchool
            .map { SchoolCreditLine(schoolID: $0.key, hours: $0.value) }
            .sorted { a, b in
                let ia = known.firstIndex(of: a.schoolID) ?? known.count
                let ib = known.firstIndex(of: b.schoolID) ?? known.count
                return ia != ib ? ia < ib : a.schoolID < b.schoolID
            }
    }

    /// Total hours over `lines`.
    static func totalHours(_ lines: [SchoolCreditLine]) -> Int {
        lines.reduce(0) { $0 + $1.hours }
    }
}
