import Foundation

/// One day on the calendar, without a time of day.
nonisolated struct CalendarDay: Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: Self { self }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    var yearMonth: YearMonth { YearMonth(year: year, month: month) }

    /// The first instant of the day.
    func startDate(calendar: Calendar = .current) -> Date {
        yearMonth.date(day: day, calendar: calendar)
    }

    /// 12:00 on the day. Plans store this, so a time-zone change cannot move
    /// them to another day.
    func midday(calendar: Calendar = .current) -> Date {
        let start = startDate(calendar: calendar)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    /// The half-open range from the start of this day to the start of the next.
    func dateRange(calendar: Calendar = .current) -> Range<Date> {
        let start = startDate(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return start..<end
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension YearMonth {
    /// Every day of the month, in order.
    nonisolated func days(calendar: Calendar = .current) -> [CalendarDay] {
        (1...lastDay(calendar: calendar)).map { CalendarDay(year: year, month: month, day: $0) }
    }
}
