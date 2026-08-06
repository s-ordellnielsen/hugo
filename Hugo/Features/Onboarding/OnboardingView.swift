import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var currentStatus: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("splash.subtitle")
                    Text("splash.description.1")
                    Text("splash.description.2")
                    Text("splash.section.publisherStatus.title")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .padding(.top, 32)
                    Text("splash.section.publisherStatus.description")

                    VStack(spacing: 8) {
                        ForEach(PublisherStatus.all) { status in
                            Button {
                                currentStatus = status.id
                            } label: {
                                HStack(spacing: 16) {
                                    Image(
                                        systemName: currentStatus == status.id
                                            ? "checkmark.circle.fill" : "circle"
                                    )
                                    .font(.title2)
                                    .tint(.orange)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(status.nameKey)
                                            .fontWeight(.medium)
                                            .fontDesign(.rounded)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(
                                                "publisher.status.goaltype.label.\(status.goalPeriod.label)"
                                            )
                                            Text(
                                                "publisher.status.goal.label.\(status.goal)"
                                            )
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontWeight(.regular)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color(.secondarySystemGroupedBackground)
                                )
                                .clipShape(.rect(cornerRadius: 32))
                                .tint(.primary)
                            }

                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("splash.title")
            .safeAreaInset(edge: .bottom) {
                Button {
                    onComplete()
                } label: {
                    Label(
                        "splash.action.complete",
                        systemImage: "arrow.right"
                    )
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 24))
                }
                .disabled(currentStatus == "")
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled(true)
    }

}

#Preview {
    OnboardingView(onComplete: {})
}
