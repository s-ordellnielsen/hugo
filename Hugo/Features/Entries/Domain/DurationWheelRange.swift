import Foundation

/// Which minutes the duration wheel offers for each hour. The last hour allows
/// only the minutes left up to `maxDuration`, so with a 24 hour maximum the
/// hour 24 offers only `00`.
nonisolated struct DurationWheelRange: Equatable {
    let maxDuration: TimeInterval
    let interval: Int

    init(maxDuration: TimeInterval, interval: Int) {
        self.maxDuration = maxDuration
        self.interval = max(1, interval)
    }

    var maxHours: Int { max(0, Int(maxDuration / 3600)) }

    /// The minutes the wheel shows for `hours`. An hour outside the range is
    /// treated as the nearest valid hour.
    func minuteOptions(forHours hours: Int) -> [Int] {
        let hours = min(maxHours, max(0, hours))
        let remainingSeconds = maxDuration - TimeInterval(hours * 3600)
        let ceiling = hours >= maxHours ? max(0, Int(remainingSeconds / 60)) : 59
        return Array(stride(from: 0, through: ceiling, by: interval))
    }

    /// `minutes` snapped down to the interval and limited to what `hours` offers.
    func snappedMinutes(_ minutes: Int, forHours hours: Int) -> Int {
        let snapped = (max(0, minutes) / interval) * interval
        return min(minuteOptions(forHours: hours).last ?? 0, snapped)
    }
}
