import Foundation

enum MonthlyProgressStatus: Equatable {
    case wayBelowTarget, belowTarget, onTarget, aboveTarget, wayAboveTarget

    static func make(expected: Double, current: Double) -> Self {
        guard !expected.isZero else { return .onTarget }
        let difference = current - expected
        if difference > 5 { return .wayAboveTarget }
        if difference > 2 { return .aboveTarget }
        if difference >= -2 { return .onTarget }
        if difference < -5 { return .wayBelowTarget }
        return .belowTarget
    }

    var label: String {
        switch self {
        case .wayAboveTarget: String(localized: "month.progress.status.wayabovetarget.label")
        case .aboveTarget: String(localized: "month.progress.status.abovetarget.label")
        case .onTarget: String(localized: "month.progress.status.ontarget.label")
        case .belowTarget: String(localized: "month.progress.status.belowtarget.label")
        case .wayBelowTarget: String(localized: "month.progress.status.waybelowtarget.label")
        }
    }

    var icon: String {
        switch self { case .wayAboveTarget, .aboveTarget: "chevron.up.circle.fill"; case .onTarget: "checkmark.circle.fill"; case .belowTarget, .wayBelowTarget: "chevron.down.circle.fill" }
    }
}
