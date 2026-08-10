import SwiftData
import SwiftUI

struct DefaultCategoryButton: View {
    @Environment(\.modelContext) private var context
    @State private var errorMessage: String?

    var tracker: Tracker

    var body: some View {
        Button {
            do {
                try DefaultCategoryService(context: context).setDefault(tracker.isDefault ? nil : tracker)
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            Image(systemName: tracker.isDefault ? "star.fill" : "star")
                .foregroundStyle(tracker.isDefault ? .hugoAccent : .primary)
                .contentTransition(.symbolEffect(.replace))
                .motion(Motion.feedback, value: tracker.isDefault)
        }
        .errorAlert(message: $errorMessage)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(tracker: Tracker(name: "Field Service"))
            .modelContainer(.preview)
    }
}
