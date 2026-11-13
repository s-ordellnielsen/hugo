import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var publisherStatus = ""

    @Environment(\.openURL) private var openURL

    /// A bundled Markdown page in the legal section. The raw value is the
    /// resource name under `Hugo/Resources/Markdown/Legal`.
    private enum LegalPage: String {
        case privacyPolicy = "PrivacyPolicy"
    }

    var showDismiss: Bool = false

    private static var supportEmailURL: URL? {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "SupportEmail") as? String
        else {
            return nil
        }
        let version = AppVersion.current
        let subject = String(
            localized: "settings.contact.email.subject.\(version.marketingVersion).\(version.buildNumber)")
        return SupportEmailLink.url(address: email, subject: subject)
    }

    private static var testFlightURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TestFlightURL") as? String,
            let url = URL(string: value),
            url.scheme == "https",
            !value.contains("REPLACE_WITH_INVITE_CODE")
        else {
            return nil
        }
        return url
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: PublisherStatusSelectionView()) {
                        Label {
                            Text("account.group.main.item.publisher.status")
                            Text(
                                PublisherStatus.status(for: publisherStatus)?
                                    .nameKey
                                    ?? "account.group.main.item.publisher.status.empty"
                            )
                        } icon: {
                            Image(
                                systemName: publisherStatus != ""
                                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        }
                    }
                }

                Section {
                    NavigationLink(destination: ReportSettingsView()) {
                        Label("settings.group.settings.report", systemImage: "doc.text")
                    }
                    NavigationLink(destination: CategoryListView()) {
                        Label("settings.group.settings.category", systemImage: "square.grid.2x2")
                    }
                    NavigationLink(destination: GeneralSettingsView()) {
                        Label("settings.group.settings.general", systemImage: "gearshape")
                    }
                }

                #if SHOW_SHARE_TESTFLIGHT
                    if let testFlightURL = Self.testFlightURL {
                        Section {
                            ShareLink(item: testFlightURL) {
                                Label("settings.account.shareTestFlight", systemImage: "person.crop.circle.badge.plus")
                            }
                        } footer: {
                            Text("settings.account.shareTestFlight.description")
                        }
                    }
                #endif

                #if SHOW_JOIN_BETA
                    if let testFlightURL = Self.testFlightURL {
                        Section {
                            Link(destination: testFlightURL) {
                                Label("settings.account.joinBeta", systemImage: "testtube.2")
                            }
                        } footer: {
                            Text("settings.account.joinBeta.description")
                        }
                    }
                #endif

                if let supportEmailURL = Self.supportEmailURL {
                    Section {
                        Button {
                            openURL(supportEmailURL)
                        } label: {
                            Label("settings.contact.email", systemImage: "envelope")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        HelpView(for: LegalPage.privacyPolicy.rawValue, presentation: .pushed)
                    } label: {
                        Label("settings.legal.privacyPolicy", systemImage: "hand.raised")
                    }
                }

                #if SHOW_DEBUG_MENU
                    Section {
                        NavigationLink(destination: DebugSettingsView()) {
                            Label("debug.title", systemImage: "ant.fill")
                                .foregroundStyle(.primary)
                        }
                    } footer: {
                        Text("debug.disclaimer")
                    }
                #endif
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showDismiss {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(.preview)
}
