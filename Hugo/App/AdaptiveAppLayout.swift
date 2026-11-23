import SwiftUI

/// Picks the app's layout by width. Compact (iPhone, narrow iPad) is the tab
/// bar. Regular (iPad) is a sidebar beside the selected tab. This is the only
/// place in `App` that reads the size class for layout.
///
/// Compact gives each tab its own stack through `tabContent`. Regular has one
/// stack for the detail column, rooted at the selected tab. Each tab's pushed
/// pages live in `AppNavigationState`, so they come back when the tab does.
struct AdaptiveAppLayout<TabContent: View>: View {
    let navigation: AppNavigationState
    let tabContent: (AppTab) -> TabContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { navigation.selectedTab },
            set: { navigation.select($0) }
        )
    }

    /// The path of the selected tab. Overview and Planner push nothing, so they
    /// get an empty path that is never written back.
    private var detailPath: Binding<NavigationPath> {
        Binding(
            get: {
                switch navigation.selectedTab {
                case .year: navigation.yearPath
                case .settings: navigation.settingsPath
                case .overview, .planner: NavigationPath()
                }
            },
            set: { newValue in
                switch navigation.selectedTab {
                case .year: navigation.yearPath = newValue
                case .settings: navigation.settingsPath = newValue
                case .overview, .planner: break
                }
            }
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
        .onChange(of: isCompact) { _, compact in
            navigation.ensureSelectionVisible(compact: compact)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases.filter { $0.placement.isVisible(compact: true) }) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    tabContent(tab)
                }
                .defaultVisibility(tab.placement.showsInTabBar ? .automatic : .hidden, for: .tabBar)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    /// The sidebar rows are buttons, not a selection binding, so tapping the
    /// selected row again still reaches `select(_:)` and resets that tab.
    private var regularLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases) { tab in
                Button {
                    navigation.select(tab)
                } label: {
                    Label(tab.titleKey, systemImage: tab.systemImage)
                }
                .accessibilityAddTraits(tab == navigation.selectedTab ? .isSelected : [])
            }
        } detail: {
            // One stack for the whole detail. A tab switch changes the root and
            // the path together, so no hidden stack keeps a stale destination.
            NavigationStack(path: detailPath) {
                tabDestination(
                    for: navigation.selectedTab,
                    yearResetToken: navigation.yearResetToken,
                    plannerResetToken: navigation.plannerResetToken,
                    displayedYear: Binding(
                        get: { navigation.displayedYear },
                        set: { navigation.displayedYear = $0 }
                    ),
                    displayedMonth: Binding(
                        get: { navigation.displayedMonth },
                        set: { navigation.displayedMonth = $0 }
                    )
                )
            }
        }
    }
}
