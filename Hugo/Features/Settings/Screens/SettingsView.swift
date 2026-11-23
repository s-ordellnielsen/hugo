import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UserDefaultsKeys.publisherStatus) var publisherStatus = ""

    @Environment(\.openURL) private var openURL
    @Environment(CloudSyncMonitor.self) private var syncMonitor: CloudSyncMonitor?

    /// A bundled Markdown page in the legal section. The raw value is the
    /// resource name under `Hugo/Resources/Markdown/Legal`.
    private enum LegalPage: String {
        case privacyPolicy = "PrivacyPolicy"
        case termsOfUse = "TermsOfUse"
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

    private static var appStoreLinks: AppStoreLinks? {
        AppStoreLinks(appleID: Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? String)
    }

    private var syncStatus: CloudSyncStatus {
        syncMonitor?.status ?? .upToDate(lastSync: nil)
    }

    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute) -> some View {
        switch route {
        case .publisherStatus: PublisherStatusSelectionView()
        case .report: ReportSettingsView()
        case .categories: CategoryListView()
        case .general: GeneralSettingsView()
        case .plannerTarget: PlannerTargetSettingsView()
        case .cloudSync: CloudSyncStatusView()
        case .privacyPolicy: HelpView(for: LegalPage.privacyPolicy.rawValue, presentation: .pushed)
        case .termsOfUse: HelpView(for: LegalPage.termsOfUse.rawValue, presentation: .pushed)
        #if SHOW_DEBUG_MENU
            case .debug: DebugSettingsView()
        #endif
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsRoute.publisherStatus) {
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
                NavigationLink(value: SettingsRoute.report) {
                    Label("settings.group.settings.report", systemImage: "doc.text")
                }
                NavigationLink(value: SettingsRoute.categories) {
                    Label("settings.group.settings.category", systemImage: "square.grid.2x2")
                }
                NavigationLink(value: SettingsRoute.general) {
                    Label("settings.group.settings.general", systemImage: "gearshape")
                }
            } header: {
                Text("settings.title")
            }

            Section {
                NavigationLink(value: SettingsRoute.cloudSync) {
                    LabeledContent {
                        Text(syncStatus.title).foregroundStyle(.secondary)
                    } label: {
                        Label("settings.sync.title", systemImage: syncStatus.symbolName)
                    }
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

            #if SHOW_APP_STORE_LINKS
                if let appStoreLinks = Self.appStoreLinks {
                    Section {
                        Link(destination: appStoreLinks.reviewURL) {
                            Label("settings.appStore.review", systemImage: "star")
                        }
                        ShareLink(
                            item: appStoreLinks.productURL,
                            message: Text("settings.appStore.recommend.message")
                        ) {
                            Label("settings.appStore.recommend", systemImage: "square.and.arrow.up")
                        }
                    } footer: {
                        Text("settings.appStore.footer")
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
                NavigationLink(value: SettingsRoute.privacyPolicy) {
                    Label("settings.legal.privacyPolicy", systemImage: "hand.raised")
                }
                NavigationLink(value: SettingsRoute.termsOfUse) {
                    Label("settings.legal.termsOfUse", systemImage: "doc.plaintext")
                }
            }

            #if SHOW_DEBUG_MENU
                Section {
                    NavigationLink(value: SettingsRoute.debug) {
                        Label("debug.title", systemImage: "ant.fill")
                            .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("debug.disclaimer")
                }
            #endif
        }
        .editorialNavigationTitle("settings.title")
        .task { await syncMonitor?.refreshAccount() }
        .navigationDestination(for: SettingsRoute.self) { route in
            settingsDestination(for: route)
        }
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

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(.preview)
}
