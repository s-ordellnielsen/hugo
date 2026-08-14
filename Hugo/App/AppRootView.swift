import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("isOnboarding") private var needsOnboarding = true

    @State private var bootstrapper = AppBootstrapper()
    @State private var selectedTab: AppTab = .overview
    @State private var yearResetToken = UUID()
    @State private var bootstrapErrorMessage: String?

    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var visibleTabs: [AppTab] {
        AppTab.allCases.filter { $0.placement.isVisible(compact: isCompact) }
    }

    private func select(_ tab: AppTab) {
        if tab == .year && selectedTab == .year {
            yearResetToken = UUID()
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
        .task { await bootstrapper.start(context: context) }
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
        .onChange(of: bootstrapper.errorMessage) { _, newValue in bootstrapErrorMessage = newValue }
        .errorAlert(message: $bootstrapErrorMessage, retry: { Task { await bootstrapper.retry(context: context) } })
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(visibleTabs) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    tabDestination(for: tab, yearResetToken: yearResetToken)
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
            tabDestination(for: selectedTab, yearResetToken: yearResetToken)
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
func tabDestination(for tab: AppTab, yearResetToken: UUID) -> some View {
    switch tab {
    case .overview: OverviewView()
    case .year: ServiceYearView(resetToken: yearResetToken)
    }
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case year

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .overview: return "tab.overview"
        case .year: return "tab.year"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "house"
        case .year: "tray.full.fill"
        }
    }

    var placement: TabPlacement {
        switch self {
        case .overview: .all
        case .year: .all
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
