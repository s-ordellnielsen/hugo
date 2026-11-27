import WidgetKit

struct MonthProgressEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

/// Reads the App Group store once per timeline. The widget reloads once a day, just after midnight.
struct MonthProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthProgressEntry {
        MonthProgressEntry(date: .now, state: .ready(MonthProgress.sample))
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthProgressEntry) -> Void) {
        let state: WidgetState = context.isPreview ? .ready(MonthProgress.sample) : currentState()
        completion(MonthProgressEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthProgressEntry>) -> Void) {
        let now = Date.now
        let entry = MonthProgressEntry(date: now, state: currentState(now: now))
        completion(Timeline(entries: [entry], policy: .after(Self.nextRefresh(after: now))))
    }

    private func currentState(now: Date = .now) -> WidgetState {
        WidgetStoreReader.production().load(now: now, calendar: .current)
    }

    /// One minute after the start of tomorrow, so the month rolls over on time.
    static func nextRefresh(after now: Date, calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        return calendar.date(byAdding: .minute, value: 1, to: startOfTomorrow) ?? startOfTomorrow
    }
}

extension MonthProgress {
    /// Sample numbers for the placeholder and the widget gallery: 32 of 50 hours.
    static var sample: MonthProgress {
        let seconds: TimeInterval = 32 * 3_600
        return MonthProgress(
            month: YearMonth(year: 2026, month: 11),
            loggedSeconds: seconds,
            goalHours: 50,
            fill: MonthlyCircleFill(basis: .monthlyGoal(hours: 50), fraction: seconds / (50 * 3_600)))
    }
}
