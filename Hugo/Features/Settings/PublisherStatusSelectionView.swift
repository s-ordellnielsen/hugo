import SwiftUI

struct PublisherStatusSelectionView: View {
    @AppStorage(UserDefaultsKeys.publisherStatus) var currentStatus: String = ""

    var body: some View {
        List {
            CurrentPublisherStatusView(currentStatus: currentStatus)

            Section {
                PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .list)
            }
        }
        .navigationTitle("account.page.publisherstatus.title")
    }
}

private struct CurrentPublisherStatusView: View {
    var currentStatus: String

    var body: some View {
		VStack(spacing: 16) {
            Image(
                systemName: PublisherStatus.status(for: currentStatus) != nil
                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle"
            )
            .font(.largeTitle)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
            .symbolRenderingMode(.hierarchical)
			.foregroundStyle(.tint)

            VStack(spacing: 4) {
				Text(PublisherStatus.status(for: currentStatus)?.nameKey ?? "publisher.status.empty")
					.font(.title2)
					.fontDesign(.rounded)
					.contentTransition(.interpolate)
					.animation(.easeInOut(duration: 0.2), value: currentStatus)
                Text("account.page.publisherselect.current")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
		.frame(maxWidth: .infinity)
        .fontWeight(.semibold)
    }
}

#Preview {
    PublisherStatusSelectionView()
}
