import SwiftUI

struct MonthlyProgressDetailView: View {
    let month: YearMonth
    var body: some View {
        NavigationStack {
            ScrollView { CategoryProgressBreakdownView(month: month).padding() }.navigationTitle(
                "monthlyReport.detailView.title")
        }
    }
}
