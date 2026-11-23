import Foundation
import Testing

@testable import Hugo

struct DurationWheelRangeTests {
    private let day = DurationWheelRange(maxDuration: 24 * 3600, interval: 5)

    @Test
    func hour24OffersOnlyZeroMinutes() {
        #expect(day.minuteOptions(forHours: 24) == [0])
    }

    @Test
    func hour23OffersAllMinutesAtTheInterval() {
        #expect(day.minuteOptions(forHours: 23) == Array(stride(from: 0, through: 55, by: 5)))
    }

    @Test
    func anHourBeyondTheRangeIsTreatedAsTheLastHour() {
        #expect(day.minuteOptions(forHours: 25) == [0])
        #expect(day.minuteOptions(forHours: -1) == day.minuteOptions(forHours: 0))
    }

    @Test
    func snappingAtHour24NeverLeavesZero() {
        #expect(day.snappedMinutes(15, forHours: 24) == 0)
        #expect(day.snappedMinutes(59, forHours: 24) == 0)
    }

    @Test
    func snappingRoundsDownToTheInterval() {
        #expect(day.snappedMinutes(17, forHours: 3) == 15)
    }

    @Test
    func aPartialLastHourOffersTheMinutesLeft() {
        let range = DurationWheelRange(maxDuration: 25 * 3600 + 30 * 60, interval: 15)
        #expect(range.minuteOptions(forHours: 25) == [0, 15, 30])
        #expect(range.minuteOptions(forHours: 24) == [0, 15, 30, 45])
    }

    @Test
    func aZeroIntervalDoesNotTrap() {
        let range = DurationWheelRange(maxDuration: 3600, interval: 0)
        #expect(range.minuteOptions(forHours: 0).count == 60)
    }
}
