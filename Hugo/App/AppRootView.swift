import CloudKit
import Combine
import CoreData
import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(UserDefaultsKeys.isOnboarding) private var needsOnboarding = true

    @State private var bootstrapper = AppBootstrapper()
    @State private var navigation = AppNavigationState()
    @State private var bootstrapErrorMessage: String?
    @State private var syncMonitor = CloudSyncMonitor()
    @State private var deduplication = SyncDeduplicationScheduler()

    /// Copies the synced settings to and from iCloud. `nil` in the unit-test
    /// host, so tests never touch the real iCloud store.
    private let settingsSync: SettingsSyncService?

    init(settingsSync: SettingsSyncService? = nil) {
        self.settingsSync = settingsSync
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var visibleTabs: [AppTab] {
        AppTab.allCases.filter { $0.placement.isVisible(compact: isCompact) }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { navigation.selectedTab },
            set: { navigation.select($0) }
        )
    }

    var body: some View {
        tabs
            .environment(syncMonitor)
            .task {
                settingsSync?.start()
                syncMonitor.startWatchingNetwork()
                await bootstrapper.start(context: context)
                deduplication.request(context: context)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { deduplication.request(context: context) }
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                    .receive(on: RunLoop.main)
            ) { notification in
                guard
                    let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else { return }
                syncMonitor.record(
                    id: event.identifier,
                    endDate: event.endDate,
                    succeeded: event.succeeded,
                    errorCode: (event.error as? CKError)?.code.rawValue
                )
                guard event.type == .import, event.endDate != nil else { return }
                deduplication.request(context: context)
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                settingsSync?.pullFromCloud()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: UserDefaults.didChangeNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                settingsSync?.pushToCloud()
            }
            .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
            .onChange(of: bootstrapper.errorMessage) { _, newValue in bootstrapErrorMessage = newValue }
            .errorAlert(message: $bootstrapErrorMessage, retry: { Task { await bootstrapper.retry(context: context) } })
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        tabDestination(
                            for: tab,
                            yearResetToken: navigation.yearResetToken,
                            plannerResetToken: navigation.plannerResetToken)
                    }
                }
                .defaultVisibility(tab.placement.showsInTabBar ? .automatic : .hidden, for: .tabBar)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: isCompact) { _, compact in
            navigation.ensureSelectionVisible(compact: compact)
        }
    }
}

@ViewBuilder
func tabDestination(for tab: AppTab, yearResetToken: UUID, plannerResetToken: UUID) -> some View {
    switch tab {
    case .overview: OverviewView()
    case .year: ServiceYearView(resetToken: yearResetToken)
    case .planner: PlannerView(resetToken: plannerResetToken)
    case .settings: SettingsView()
    }
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case planner
    case year
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .overview: return "tab.overview"
        case .year: return "tab.year"
        case .planner: return "tab.planner"
        case .settings: return "tab.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "house"
        case .year: "tray.full.fill"
        case .planner: "calendar"
        case .settings: "switch.2"
        }
    }

    var placement: TabPlacement {
        switch self {
        case .overview: .all
        case .year: .all
        case .planner: .all
        case .settings: .sidebarOnly
        }
    }
}

enum TabPlacement {
    case sidebarOnly
    case all

    /// Whether the tab gets an item in the tab bar. A sidebar-only tab is listed
    /// in the sidebar and reached from a toolbar button on a compact screen.
    var showsInTabBar: Bool {
        switch self {
        case .sidebarOnly: false
        case .all: true
        }
    }

    func isVisible(compact: Bool) -> Bool {
        switch self {
        case .sidebarOnly: !compact
        case .all: true
        }
    }
}
