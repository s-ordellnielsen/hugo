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
                        .padding(.horizontal, 4)
                    Text("splash.description.1")
                        .padding(.horizontal, 4)
                    Text("splash.description.2")
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("splash.section.publisherStatus.title")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .padding(.horizontal, 4)
                        Text("splash.section.publisherStatus.description")
                            .font(.caption)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            PublisherStatusOptionsView(selection: $currentStatus, rowStyle: .card)
                        }
                        .padding(.top, 16)
                    }
                    .padding(.top, 32)
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
                    .background(.hugoAccent)
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
