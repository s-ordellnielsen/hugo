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

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { select($0) }
        )
    }

    var body: some View {
        Group {
            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .task {
            await bootstrapper.start(context: context)
            SyncDeduplicator(context: context).run()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { SyncDeduplicator(context: context).run() }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                .receive(on: RunLoop.main)
        ) { notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                event.type == .import, event.endDate != nil
            else { return }
            SyncDeduplicator(context: context).run()
        }
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
        .onChange(of: bootstrapper.errorMessage) { _, newValue in bootstrapErrorMessage = newValue }
        .errorAlert(message: $bootstrapErrorMessage, retry: { Task { await bootstrapper.retry(context: context) } })
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    tabDestination(for: tab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
                }
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(
                visibleTabs,
                id: \.self,
                selection: sidebarSelection
            ) { tab in
                Label(tab.titleKey, systemImage: tab.systemImage)
            }
        } detail: {
            tabDestination(for: selectedTab, yearResetToken: yearResetToken, plannerResetToken: plannerResetToken)
        }
    }

    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if let newValue {
                    select(newValue)
                }
            }
        )
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
    case compactOnly
    case sidebarOnly
    case all

    func isVisible(compact: Bool) -> Bool {
        switch self {
        case .compactOnly: compact
        case .sidebarOnly: !compact
        case .all: true
        }
    }
}
