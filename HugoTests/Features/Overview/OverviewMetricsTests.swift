import Foundation
import Testing

@testable import Hugo

@MainActor
struct OverviewMetricsTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    @Test
    func currentMonthUsesHalfOpenIntervalAcrossDecember() {
        let now = date(2026, 12, 15)
        let interval = CurrentMonthInterval.current(now: now, calendar: calendar)
        #expect(calendar.component(.month, from: interval.start) == 12)
        #expect(calendar.component(.year, from: interval.end) == 2027)
        #expect(calendar.component(.month, from: interval.end) == 1)
    }

    @Test
    func metricsCalculateGoalAndExpectedProgress() {
        let status = PublisherStatus.status(for: "auxiliary-pioneer")
        let metrics = OverviewMetrics.make(
            entries: [Entry(date: date(2026, 1, 1), duration: 7_200, tracker: nil)], status: status,
            now: date(2026, 1, 15), calendar: calendar)
        #expect(metrics.totalHours == 2)
        #expect(metrics.monthlyGoal == 30)
        #expect(abs(metrics.expectedProgress - (15.0 / 31.0 * 30.0)) < 0.0001)
    }

    @Test
    func missingStatusAndNegativeDurationsAreSafe() {
        let metrics = OverviewMetrics.make(
            entries: [Entry(date: date(2026, 1, 1), duration: -100, tracker: nil)], status: nil, now: date(2026, 1, 1),
            calendar: calendar)
        #expect(metrics.totalHours == 0)
        #expect(metrics.monthlyGoal == 0)
        #expect(metrics.expectedProgress == 0)
    }

    @Test
    func validTrackerColorIsPreserved() {
        let tracker = Tracker(name: "Colored", hue: 0.25, sat: 0.5, bri: 0.75)
        let rows = CategoryProgressAggregator.rows(
            entries: [Entry(date: date(2026, 1, 1), duration: 100, tracker: tracker)], trackers: [tracker])
        #expect(rows.first?.color == CategoryProgressColor(hue: 0.25, saturation: 0.5, brightness: 0.75))
    }

    @Test
    func defaultBrightnessUsesFallbackColor() {
        let tracker = Tracker(name: "Unassigned")
        let rows = CategoryProgressAggregator.rows(
            entries: [Entry(date: date(2026, 1, 1), duration: 100, tracker: tracker)], trackers: [tracker])
        #expect(rows.first?.color == nil)
    }

    @Test
    func invalidTrackerColorUsesFallbackColor() {
        let tracker = Tracker(name: "Invalid", hue: 1.5, sat: 0.5, bri: 0.5)
        let rows = CategoryProgressAggregator.rows(
            entries: [Entry(date: date(2026, 1, 1), duration: 100, tracker: tracker)], trackers: [tracker])
        #expect(rows.first?.color == nil)
    }

    @Test
    func untrackedEntriesBecomeFallbackRows() {
        let rows = CategoryProgressAggregator.rows(
            entries: [Entry(date: date(2026, 1, 1), duration: 150, tracker: nil)], trackers: [])
        #expect(rows.count == 1)
        #expect(rows.first?.id == "untracked")
        #expect(rows.first?.duration == 150)
        #expect(rows.first?.color == nil)
    }

    @Test
    func categoryRowsConserveTrackedAndUntrackedDuration() {
        let tracker = Tracker(name: "Tracked")
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 100, tracker: tracker),
            Entry(date: date(2026, 1, 2), duration: 200, tracker: nil),
        ]
        let rows = CategoryProgressAggregator.rows(entries: entries, trackers: [tracker])
        #expect(rows.map(\.duration).reduce(0, +) == 300)
    }

    @Test
    func categoryRowsConserveDuration() {
        let first = Tracker(name: "First")
        let second = Tracker(name: "Second")
        let entries = [
            Entry(date: date(2026, 1, 1), duration: 100, tracker: first),
            Entry(date: date(2026, 1, 2), duration: 200, tracker: second),
        ]
        let rows = CategoryProgressAggregator.rows(entries: entries, trackers: [first, second])
        #expect(rows.map(\.duration).reduce(0, +) == 300)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
