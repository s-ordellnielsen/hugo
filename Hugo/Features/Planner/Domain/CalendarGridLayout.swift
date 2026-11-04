import Foundation

/// Where a month's days fall in a seven-column calendar grid.
nonisolated enum CalendarGridLayout {
    /// Very short weekday names, starting at the calendar's first weekday.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Empty cells before the month's first day.
    static func leadingBlankDays(in month: YearMonth, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: month.date(calendar: calendar))
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
