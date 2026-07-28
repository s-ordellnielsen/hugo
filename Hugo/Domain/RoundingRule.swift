import Foundation

nonisolated enum RoundingRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case up
    case down
    case transfer

    var id: String { rawValue }

    var nameKey: String {
        "rounding-rule.\(rawValue)"
    }
}
