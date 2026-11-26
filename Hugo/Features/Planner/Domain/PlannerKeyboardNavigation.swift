import Foundation

/// One arrow-key step in the Planner calendar.
nonisolated enum PlannerKeyboardMove: Sendable {
    case previousDay
    case nextDay
    case previousWeek
    case nextWeek

    var dayOffset: Int {
        switch self {
        case .previousDay: -1
        case .nextDay: 1
        case .previousWeek: -7
        case .nextWeek: 7
        }
    }
}

/// Where the keyboard highlight goes in a Planner month. The highlight never
/// leaves the month: months change only with ⌘← and ⌘→.
nonisolated enum PlannerKeyboardNavigation {
    /// The day the highlight starts on: today in the current month, otherwise the 1st.
    static func startDay(in month: YearMonth, today: CalendarDay) -> CalendarDay {
        today.yearMonth == month ? today : CalendarDay(year: month.year, month: month.month, day: 1)
    }

    /// The highlighted day after `move`. Without a highlighted day in `month`,
    /// the first press only shows the highlight on the start day. A move that
    /// would leave the month keeps the current day.
    static func day(
        after move: PlannerKeyboardMove, from day: CalendarDay?, in month: YearMonth, today: CalendarDay,
        calendar: Calendar = .current
    ) -> CalendarDay {
        guard let day, day.yearMonth == month else { return startDay(in: month, today: today) }
        let target = day.day + move.dayOffset
        guard (1...month.lastDay(calendar: calendar)).contains(target) else { return day }
        return CalendarDay(year: month.year, month: month.month, day: target)
    }
}
