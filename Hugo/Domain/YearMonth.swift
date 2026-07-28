import Foundation

nonisolated struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }
}

extension YearMonth {
    nonisolated func nextMonth(calendar: Calendar = .current) -> YearMonth {
        let start = date(calendar: calendar)
        guard let next = calendar.date(byAdding: .month, value: 1, to: start) else {
            return month == 12
                ? YearMonth(year: year + 1, month: 1)
                : YearMonth(year: year, month: month + 1)
        }
        return next.yearMonth(using: calendar)
    }

    nonisolated static func previous(before month: YearMonth, calendar: Calendar = .current) -> YearMonth {
        let start = month.date(calendar: calendar)
        guard let previous = calendar.date(byAdding: .month, value: -1, to: start) else {
            return month.month == 1
                ? YearMonth(year: month.year - 1, month: 12)
                : YearMonth(year: month.year, month: month.month - 1)
        }
        return previous.yearMonth(using: calendar)
    }

    nonisolated func lastDay(calendar: Calendar = .current) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date(calendar: calendar)) else {
            return 31
        }
        return range.count
    }

    nonisolated func endDate(calendar: Calendar = .current) -> Date {
        let startOfNextMonth = nextMonth(calendar: calendar).date(calendar: calendar)
        return calendar.date(byAdding: .second, value: -1, to: startOfNextMonth) ?? startOfNextMonth
    }
}

extension Date {
    nonisolated func yearMonth(using calendar: Calendar = .current) -> YearMonth {
        let components = calendar.dateComponents([.year, .month], from: self)
        return YearMonth(year: components.year ?? 0, month: components.month ?? 0)
    }
}

extension YearMonth {
    nonisolated func monthYearString(locale: Locale = .current, calendar: Calendar = .current) -> String {
        var components = DateComponents()
		
        components.year = year
        components.month = month
		
        guard let date = calendar.date(from: components) else { return "\(month)/\(year)" }
		
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
		
        return formatter.string(from: date)
    }

    nonisolated func monthName(locale: Locale = .current, calendar: Calendar = .current) -> String {
        var components = DateComponents()

        components.year = year
        components.month = month

        guard let date = calendar.date(from: components) else { return "\(month)" }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL"

        return formatter.string(from: date)
    }
	
	nonisolated func date(day: Int = 1, calendar: Calendar = .current) -> Date {
		var components = DateComponents()
		
		components.year = year
		components.month = month
		components.day = day
		
		return calendar.date(from: components) ?? .now
	}
}
