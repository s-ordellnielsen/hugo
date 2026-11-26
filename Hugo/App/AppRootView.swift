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
    @State private var selectedTab: AppTab = .overview
    @State private var yearResetToken = UUID()
    @State private var plannerResetToken = UUID()
    @State private var bootstrapErrorMessage: String?
    @State private var syncMonitor = CloudSyncMonitor()
    @State private var deduplication = SyncDeduplicationScheduler()
    @State private var isAddingEntry = false
    @State private var isShowingSettingsSheet = false

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

    private func select(_ tab: AppTab) {
        if tab == .year && selectedTab == .year {
            yearResetToken = UUID()
        }
        if tab == .planner && selectedTab == .planner {
            plannerResetToken = UUID()
        }
        selectedTab = tab
    }

    private var commandActions: AppCommandActions {
        AppCommandActions(
            selectedTab: selectedTab,
            addEntry: { if !needsOnboarding { isAddingEntry = true } },
            select: { select($0) },
            showToday: showToday,
            showSettings: showSettings
        )
    }

    /// Scrolls the Planner or the Service Year back to now, like selecting its tab again.
    private func showToday() {
        switch selectedTab {
        case .planner: plannerResetToken = UUID()
        case .year: yearResetToken = UUID()
        case .overview, .settings: break
        }
    }

    /// The Settings tab when the sidebar lists it, otherwise the same sheet as the
    /// toolbar's settings button.
    private func showSettings() {
        if AppTab.settings.placement.isVisible(compact: isCompact) {
            select(.settings)
        } else {
            isShowingSettingsSheet = true
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { select($0) }
        )
    }

    var body: some View {
        tabs
            .focusedSceneValue(\.appCommands, commandActions)
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
            .sheet(isPresented: $isAddingEntry) { AddEntryView() }
            .sheet(isPresented: $isShowingSettingsSheet) {
                NavigationStack {
                    SettingsView(showDismiss: true)
                }
                .presentationDetents([.large])
            }
            .onChange(of: bootstrapper.errorMessage) { _, newValue in bootstrapErrorMessage = newValue }
            .errorAlert(message: $bootstrapErrorMessage, retry: { Task { await bootstrapper.retry(context: context) } })
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                    }
                    // The tab view's mint is for the sidebar selection only; content stays monochrome.
                    .tint(.primary)
                }
                .defaultVisibility(tab.placement.showsInTabBar ? .automatic : .hidden, for: .tabBar)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Mint selection in the iPad sidebar, where a primary (white in dark mode) capsule hides its label. Compact width keeps the iPhone tab bar as it was.
        .tint(isCompact ? Color.primary : Color.hugoAccent)
        .onChange(of: isCompact) { _, compact in
            if compact && !selectedTab.placement.isVisible(compact: true) {
                selectedTab = .overview
            }
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

    /// The digit for ⌘1, ⌘2 and ⌘3, in tab bar order. Settings uses ⌘, instead.
    var commandDigit: Character? {
        switch self {
        case .overview: "1"
        case .planner: "2"
        case .year: "3"
        case .settings: nil
        }
    }

    /// Whether Go to Today does something on this tab.
    var showsTodayCommand: Bool {
        switch self {
        case .planner, .year: true
        case .overview, .settings: false
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
