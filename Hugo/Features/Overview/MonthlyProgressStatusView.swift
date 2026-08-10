import SwiftUI

struct MonthlyProgressStatusView: View {
    let expected: Double
    let current: Double
    var body: some View {
        let status = MonthlyProgressStatus.make(expected: expected, current: current)
        return HStack {
            Image(systemName: status.icon)
            Text(status.label)
        }.fontWeight(.semibold)
    }
}
