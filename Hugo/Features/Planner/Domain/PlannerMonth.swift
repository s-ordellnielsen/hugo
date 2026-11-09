import Foundation

/// Main and separate time kept apart, so the yearly goal's credit rule can apply.
nonisolated struct TimeSplit: Equatable, Sendable {
    var main: TimeInterval = 0
    var separate: TimeInterval = 0

    static let zero = TimeSplit()

    var total: TimeInterval { main + separate }

    /// Untracked time (`type == nil`) counts as main, as on the Field Service line.
    mutating func add(_ seconds: TimeInterval, type: TrackerType?) {
        if type == .separate { separate += seconds } else { main += seconds }
    }

    /// What is left of `self` once `covered` is taken off, per kind, never below zero.
    func remaining(after covered: TimeSplit) -> TimeSplit {
        TimeSplit(main: max(0, main - covered.main), separate: max(0, separate - covered.separate))
    }

    static func + (lhs: TimeSplit, rhs: TimeSplit) -> TimeSplit {
        TimeSplit(main: lhs.main + rhs.main, separate: lhs.separate + rhs.separate)
    }
}

/// One day of a Planner month.
nonisolated struct PlannerDay: Identifiable, Equatable, Sendable {
    let id: CalendarDay
    let logged: TimeSplit
    let planned: TimeSplit
    /// Plan bars, one per category in the order of each category's first plan,
    /// then unplanned bars.
    let bars: [PlannerBar]
    let isToday: Bool
    let isPast: Bool

    /// `items` and `entries` must already belong to `day`. `trackers` give the
    /// colors of logged categories. Carried-in entries are skipped: their time was not logged on this day.
    static func make(
        day: CalendarDay,
        items: [PlannedItem],
        entries: [Entry],
        trackers: [Tracker],
        today: CalendarDay
    ) -> PlannerDay {
        var planned = TimeSplit.zero
        for item in items {
            planned.add(item.duration, type: item.categoryType)
        }

        var logged = TimeSplit.zero
        var byCategory: [String: LoggedCategoryTime] = [:]
        for entry in entries where !entry.isCarriedIn {
            let seconds = max(entry.duration, 0)
            let category = entry.resolvedCategory()
            logged.add(seconds, type: category.type)
            if byCategory[category.key] == nil {
                let tracker = category.trackerID.flatMap { id in trackers.first { $0.id == id } }
                byCategory[category.key] = LoggedCategoryTime(
                    key: category.key, name: category.name, iconName: category.iconName, type: category.type,
                    color: tracker?.categoryColor,
                    seconds: 0)
            }
            byCategory[category.key]?.seconds += seconds
        }

        return PlannerDay(
            id: day, logged: logged, planned: planned,
            bars: PlanMatcher.bars(plans: items, logged: Array(byCategory.values)),
            isToday: day == today, isPast: day < today)
    }
}

/// A month in the Planner: logged and planned time for each day, and the
/// month's still-planned and projected time.
nonisolated struct PlannerMonth: Equatable, Sendable {
    let month: YearMonth
    let today: CalendarDay
    let days: [PlannerDay]
    /// Time from carried-in entries. It is on no day, but it counts toward
    /// the month, as it does on the month's report.
    let carriedIn: TimeSplit

    var hasPlans: Bool { days.contains { $0.planned.total > 0 } }

    var logged: TimeSplit { days.reduce(carriedIn) { $0 + $1.logged } }

    var planned: TimeSplit { days.reduce(.zero) { $0 + $1.planned } }

    /// Planned time on today and later days that logged time has not yet covered.
    var stillPlanned: TimeSplit {
        days.filter { $0.id >= today }.reduce(.zero) { $0 + $1.planned.remaining(after: $1.logged) }
    }

    /// Logged time plus still-planned time.
    var projected: TimeSplit { logged + stillPlanned }

    /// Entries and items outside `month` are ignored.
    static func make(
        month: YearMonth,
        items: [PlannedItem],
        entries: [Entry],
        trackers: [Tracker] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PlannerMonth {
        let today = CalendarDay(now, calendar: calendar)
        let entriesByDay = Dictionary(grouping: entries) { CalendarDay($0.date, calendar: calendar) }
        let itemsByDay = Dictionary(grouping: items, by: \.day)
        let days = month.days(calendar: calendar).map { day in
            PlannerDay.make(
                day: day, items: itemsByDay[day] ?? [], entries: entriesByDay[day] ?? [],
                trackers: trackers, today: today)
        }
        let monthDays = Set(days.map(\.id))
        var carriedIn = TimeSplit.zero
        for entry in entries where entry.isCarriedIn {
            guard monthDays.contains(CalendarDay(entry.date, calendar: calendar)) else { continue }
            carriedIn.add(max(entry.duration, 0), type: entry.resolvedCategory().type)
        }
        return PlannerMonth(month: month, today: today, days: days, carriedIn: carriedIn)
    }

    /// The months the Planner pages through: the current month and the next 11.
    static func reachableMonths(from now: Date = .now, calendar: Calendar = .current) -> [YearMonth] {
        var month = now.yearMonth(using: calendar)
        var months: [YearMonth] = []
        for _ in 0..<12 {
            months.append(month)
            month = month.nextMonth(calendar: calendar)
        }
        return months
    }
}
