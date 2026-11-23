import SwiftData
import SwiftUI

struct DefaultCategoryButton: View {
    @AppStorage(UserDefaultsKeys.defaultCategoryID) private var defaultCategoryID: String?
    @Query private var trackers: [Tracker]

    var tracker: Tracker

    private var isDefault: Bool {
        DefaultCategory.resolve(storedID: defaultCategoryID, in: trackers)?.id == tracker.id
    }

    var body: some View {
        Button {
            DefaultCategoryService().setDefault(isDefault ? nil : tracker)
        } label: {
            Label("tracker.options.use-as-default", systemImage: isDefault ? "star.fill" : "star")
                .labelStyle(.iconOnly)
                .foregroundStyle(isDefault ? .hugoAccent : .primary)
                .contentTransition(.symbolEffect(.replace))
                .motion(Motion.feedback, value: isDefault)
        }
        .accessibilityAddTraits(isDefault ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(tracker: Tracker(name: "Field Service"))
            .modelContainer(.preview)
    }
}
