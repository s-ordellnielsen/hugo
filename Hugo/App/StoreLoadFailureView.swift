import SwiftUI

/// Shown in place of the app when the data store can't open. It explains that
/// nothing was deleted and offers Retry, Contact Us and the error details.
struct StoreLoadFailureView: View {
    let report: StoreLoadFailureReport
    let retry: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var supportMailURL: URL? {
        let email = Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String ?? ""
        return report.mailURL(to: email, subject: String(localized: "launch.failure.email.subject"))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HugoLayout.Spacing.regular) {
                ContentUnavailableView {
                    Label {
                        Text("launch.failure.title")
                            .fontDesign(.serif)
                    } icon: {
                        Image(systemName: "externaldrive.badge.exclamationmark")
                    }
                } description: {
                    Text("launch.failure.message")
                } actions: {
                    Button("common.retry", action: retry)
                        .buttonStyle(.borderedProminent)
                    if let supportMailURL {
                        Button("settings.contact.email") {
                            openURL(supportMailURL)
                        }
                    }
                }

                DisclosureGroup("launch.failure.details") {
                    Text(verbatim: report.text)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, HugoLayout.Spacing.small)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { retry() }
        }
    }
}

#Preview {
    StoreLoadFailureView(
        report: StoreLoadFailureReport(
            errorDetails: "Error Domain=NSCocoaErrorDomain Code=134110",
            appVersion: "1.0",
            buildNumber: "125"
        ),
        retry: {}
    )
}
