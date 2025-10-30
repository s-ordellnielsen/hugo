//
//  YearMonth.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 28/10/2025.
//

import Foundation

struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }
}

extension Date {
    func yearMonth() -> YearMonth {
        let comps = Calendar.current.dateComponents([.year, .month], from: self)
        return YearMonth(year: comps.year ?? 0, month: comps.month ?? 0)
    }
}

extension YearMonth {
    func monthYearString(locale: Locale = .current) -> String {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let cal = Calendar.current
        guard let date = cal.date(from: comps) else { return "\(month)/\(year)" }
        let df = DateFormatter()
        df.locale = locale
        df.dateFormat = "LLLL yyyy" // full month name + year, e.g. "September 2025"
        return df.string(from: date)
    }
}
