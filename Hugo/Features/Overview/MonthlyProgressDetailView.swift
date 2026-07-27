import SwiftUI

struct MonthlyProgressDetailView: View {
    var body: some View {
        NavigationStack {
            ScrollView { CategoryProgressBreakdownView().padding() }.navigationTitle("monthlyReport.detailView.title")
        }
    }
}
