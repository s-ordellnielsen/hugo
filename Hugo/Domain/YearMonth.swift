import Foundation

nonisolated struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }
}

extension Date {
    func yearMonth(using calendar: Calendar = .current) -> YearMonth {
        let components = calendar.dateComponents([.year, .month], from: self)
        return YearMonth(year: components.year ?? 0, month: components.month ?? 0)
    }
}

extension YearMonth {
    func monthYearString(locale: Locale = .current, calendar: Calendar = .current) -> String {
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
	
	func date(day: Int = 1, calendar: Calendar = .current) -> Date {
		var components = DateComponents()
		
		components.year = year
		components.month = month
		components.day = day
		
		return calendar.date(from: components) ?? .now
	}
}
