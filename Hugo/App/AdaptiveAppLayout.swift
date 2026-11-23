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
    @State private var tapRule = SidebarTapRule()

    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { navigation.selectedTab },
            set: { navigation.select($0) }
        )
    }

    /// The sidebar selection. Setting it only switches tabs. Reselect is a
    /// separate tap, decided by `tapRule`.
    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { navigation.selectedTab },
            set: { tab in
                if let tab, tab != navigation.selectedTab {
                    navigation.selectedTab = tab
                }
            }
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

    private var regularLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: sidebarSelection) { tab in
                Label(tab.titleKey, systemImage: tab.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .tag(tab)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                tapRule.pressBegan(on: tab, selected: navigation.selectedTab)
                            }
                            .onEnded { value in
                                let travel = hypot(value.translation.width, value.translation.height)
                                if let reselected = tapRule.tapEnded(on: tab, travel: travel) {
                                    navigation.popToRoot(reselected)
                                }
                            }
                    )
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
