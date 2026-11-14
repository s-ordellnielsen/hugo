import SwiftUI

struct MonthlyProgressStatusView: View {
    let status: MonthlyProgressStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .symbolEffect(.breathe, isActive: status.isEmphasized && !reduceMotion)
            Text(status.label)
        }
        .fontWeight(.semibold)
    }
}
