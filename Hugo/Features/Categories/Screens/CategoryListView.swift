import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Query private var trackers: [Tracker]

    @State private var addTrackerSheetIsPresented: Bool = false

    var body: some View {
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
                                    }
                                    Spacer()
                                    if tracker.isDefault {
                                        Image(systemName: "star.fill")
                                            .font(.callout)
                                            .foregroundStyle(.hugoAccent)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("screen.category-list.title")
        .toolbar {
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
