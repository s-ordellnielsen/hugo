import SwiftUI

struct PublisherStatusSelectionView: View {
    @AppStorage(UserDefaultsKeys.publisherStatus) var currentStatus: String = ""

    var body: some View {
        List {
            CurrentPublisherStatusView(currentStatus: currentStatus)

            Section {
				ForEach(PublisherStatus.all, id: \.id) { status in
                    Button {
						withAnimation(.easeOut(duration: 0.2)) {
							currentStatus = status.id
						}
                    } label: {
						HStack(alignment: .center, spacing: 12) {
							VStack(alignment: .leading, spacing: 4) {
								Text(status.nameKey)
								
								Text("This is a test")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							
							Spacer(minLength: 12)
							
							if currentStatus == status.id {
								Image(systemName: "checkmark")
									.foregroundStyle(.tint)
									.fontWeight(.semibold)
									.transition(.blurReplace.combined(with: .opacity))
							}
						}
						.contentShape(Rectangle())
                    }
					.buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("account.page.publisherstatus.title")
    }
}

private struct CurrentPublisherStatusView: View {
    var currentStatus: String

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Image(
                    systemName: PublisherStatus.status(for: currentStatus) != nil ? "circle.badge.checkmark" : "circle"
                )
                .font(.title)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading) {
                    Text("account.page.publisherselect.current")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(PublisherStatus.status(for: currentStatus)?.nameKey ?? "publisher.status.empty")
                        .font(.title2)
                        .fontDesign(.rounded)
                }
            }
            .fontWeight(.semibold)
        }
    }
}

#Preview {
    PublisherStatusSelectionView()
}
