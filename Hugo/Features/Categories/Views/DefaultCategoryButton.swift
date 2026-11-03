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
            Label("tracker.options.use-as-default", systemImage: tracker.isDefault ? "star.fill" : "star")
                .labelStyle(.iconOnly)
                .foregroundStyle(tracker.isDefault ? .hugoAccent : .primary)
                .contentTransition(.symbolEffect(.replace))
                .motion(Motion.feedback, value: tracker.isDefault)
        }
        .accessibilityAddTraits(tracker.isDefault ? .isSelected : [])
        .errorAlert(message: $errorMessage)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(tracker: Tracker(name: "Field Service"))
            .modelContainer(.preview)
    }
}
