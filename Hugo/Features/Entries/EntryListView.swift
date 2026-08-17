import SwiftUI

struct EntryListView: View {
    var entries: [Entry]

    @State var selectedEntry: Entry? = nil
	@State var showAddEntrySheet: Bool = false

    var body: some View {
        LazyVStack(spacing: 12) {
			if entries.isEmpty {
				ContentUnavailableView {
					Label {
						Text("overview.entries.empty")
							.fontDesign(.serif)
					} icon: {
						Image(systemName: "text.page.badge.magnifyingglass")
					}
				} description: {
					Text("overview.entries.empty.description")
				} actions: {
					Button("overview.entries.empty.actions.add") {
						showAddEntrySheet.toggle()
					}
				}
			} else {
				ForEach(entries) { entry in
					EntryRow(entry: entry, selectedEntry: $selectedEntry)
						.transition(.move(edge: .top).combined(with: .opacity))
				}
			}
        }
        .motion(Motion.presence, value: entries.count)
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry)
                .presentationDetents([.medium])
        }
		.sheet(isPresented: $showAddEntrySheet) {
			AddEntryView()
		}
    }
}
