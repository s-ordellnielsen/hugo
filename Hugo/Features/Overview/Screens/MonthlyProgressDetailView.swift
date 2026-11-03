import SwiftUI

struct MonthlyProgressDetailView: View {
    let month: YearMonth
    var body: some View {
        NavigationStack {
            ScrollView { CategoryProgressBreakdownView(month: month).padding() }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        EditorialNavigationTitle(title: String(localized: "monthlyReport.detailView.title"))
                    }
                }
        }
    }
}
