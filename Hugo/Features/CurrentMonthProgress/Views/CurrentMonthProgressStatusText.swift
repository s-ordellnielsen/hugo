//
//  StatusText.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 15/11/2025.
//

import SwiftUI

extension CurrentMonthProgressView {
    struct StatusText: View {
        var expectedProgress: Double
        var currentProgress: Double

        var currentStatus: MonthStatus {
            if expectedProgress.isZero {
                return .onTarget
            }

            let diff = currentProgress - expectedProgress

            if diff > 5 {
                return .wayAboveTarget
            } else if diff > 2 {
                return .aboveTarget
            } else if diff >= -2 && diff <= 2 {
                return .onTarget
            } else if diff < -5 {
                return .wayBelowTarget
            } else {
                return .belowTarget
            }
        }

        var body: some View {
            HStack {
                Image(systemName: currentStatus.icon)
                    .symbolEffect(.breathe, isActive: currentStatus.animation)
                Text(currentStatus.label)
            }
            .fontWeight(.semibold)
            .fontDesign(.rounded)
        }
    }

    enum MonthStatus {
        case wayBelowTarget
        case belowTarget
        case onTarget
        case aboveTarget
        case wayAboveTarget

        var label: String {
            switch self {
            case .wayAboveTarget:
                String(localized: "month.progress.status.wayabovetarget.label")
            case .aboveTarget:
                String(localized: "month.progress.status.abovetarget.label")
            case .onTarget:
                String(localized: "month.progress.status.ontarget.label")
            case .belowTarget:
                String(localized: "month.progress.status.belowtarget.label")
            case .wayBelowTarget:
                String(localized: "month.progress.status.waybelowtarget.label")
            }
        }

        var icon: String {
            switch self {
            case .wayAboveTarget, .aboveTarget:
                "chevron.up.circle.fill"
            case .onTarget:
                "checkmark.circle.fill"
            case .wayBelowTarget, .belowTarget:
                "chevron.down.circle.fill"
            }
        }

        var animation: Bool {
            switch self {
            case .wayBelowTarget, .wayAboveTarget:
                true
            default:
                false
            }
        }
    }
}

#Preview {
    CurrentMonthProgressView<EmptyView>.StatusText(
        expectedProgress: 24,
        currentProgress: 30
    )
}
