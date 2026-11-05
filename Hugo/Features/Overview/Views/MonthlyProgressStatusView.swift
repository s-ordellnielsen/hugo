import SwiftUI

struct MonthlyProgressStatusView: View {
    let status: MonthlyProgressStatus
    var body: some View {
        HStack {
            Image(systemName: status.icon)
            Text(status.label)
        }.fontWeight(.semibold)
    }
}
