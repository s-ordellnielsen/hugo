import Foundation

nonisolated struct TheocraticYearReport {
    let year: TheocraticYear
    let months: [ServiceMonth]
    let totalSeconds: TimeInterval
    let totalBibleStudies: Int
    let mainDuration: TimeInterval
    let separateDuration: TimeInterval

    var hasEntries: Bool { months.contains { $0.summary != nil } }
}
