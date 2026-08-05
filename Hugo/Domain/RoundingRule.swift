import Foundation

nonisolated enum RoundingRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case up
    case down
    case transfer

    var id: String { rawValue }

    var localizedName: LocalizedStringResource {
        switch self {
        case .up: "rounding-rule.up"
        case .down: "rounding-rule.down"
        case .transfer: "rounding-rule.transfer"
        }
    }
}
