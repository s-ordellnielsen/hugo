import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Query private var trackers: [Tracker]
    @AppStorage(UserDefaultsKeys.defaultCategoryID) private var defaultCategoryID: String?

    @State private var addTrackerSheetIsPresented: Bool = false

    var body: some View {
        let defaultID = DefaultCategory.resolve(storedID: defaultCategoryID, in: trackers)?.id
        List {
            ForEach(TrackerType.allCases, id: \.self) { type in
                let filtered = trackers.filter { $0.type == type }

                if !filtered.isEmpty {
                    Section(type.label) {
                        ForEach(filtered, id: \.id) { tracker in
                            NavigationLink(
                                destination: CategoryDetailView(tracker: tracker)
                            ) {
                                HStack {
                                    Label {
                                        Text(tracker.name)
                                    } icon: {
                                        Image(systemName: tracker.iconName)
                                            .foregroundStyle(CategoryColorStyle(tracker.categoryColor))
                                    }
                                    Spacer()
                                    if tracker.id == defaultID {
                                        Image(systemName: "star.fill")
                                            .font(.callout)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .readableListWidth()
        .editorialNavigationTitle("screen.category-list.title")
        .toolbar {
            ToolbarItem {
                HelpMenu(articles: HelpArticle.categories)
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button {
                    addTrackerSheetIsPresented = true
                } label: {
                    Label("navigation.add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $addTrackerSheetIsPresented) {
            AddCategoryView()
        }
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
            .modelContainer(.preview)
            .navigationBarTitleDisplayMode(.inline)
    }
}
