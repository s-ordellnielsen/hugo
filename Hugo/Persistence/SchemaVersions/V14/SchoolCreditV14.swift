//
//  SchoolCreditV14.swift
//  Hugo
//

import Foundation
import SwiftData

extension SchemaV14 {
    /// Hours of school credit for one month, such as the credit a regular
    /// pioneer gets for attending Pioneer Service School. It counts toward
    /// the yearly goal like main time. It has no relationships, so later
    /// changes to other models never need a new `SchoolCredit` class.
    @Model
    final class SchoolCredit {
        var id: UUID = UUID()
        /// `School.rawValue`. A string, so a school added by a later build
        /// syncs to older builds without breaking them.
        var schoolID: String = ""
        var year: Int = 0
        var month: Int = 0
        var hours: Int = 0
        var createdAt: Date = Date()

        init(schoolID: String, month: YearMonth, hours: Int, createdAt: Date = .now) {
            self.schoolID = schoolID
            self.year = month.year
            self.month = month.month
            self.hours = hours
            self.createdAt = createdAt
        }

        var yearMonth: YearMonth {
            YearMonth(year: year, month: month)
        }
    }
}
