import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var currentStatus: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HugoLayout.Spacing.spacious) {
                    Text("splash.subtitle")
                        .padding(.horizontal, HugoLayout.Spacing.tight)
                    Text("splash.description.1")
                        .padding(.horizontal, HugoLayout.Spacing.tight)
                    Text("splash.description.2")
                        .padding(.horizontal, HugoLayout.Spacing.tight)

                    VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                        Text("splash.section.publisherStatus.title")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, HugoLayout.Spacing.tight)
                        Text("splash.section.publisherStatus.description")
                            .font(.caption)
                            .padding(.horizontal, HugoLayout.Spacing.tight)

                        VStack(spacing: HugoLayout.Spacing.compact) {
                            PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .card)
                        }
                        .padding(.top, HugoLayout.Spacing.spacious)
                    }
                    .padding(.top, HugoLayout.Spacing.section)
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
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.hugoAccent)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.compactCard))
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
