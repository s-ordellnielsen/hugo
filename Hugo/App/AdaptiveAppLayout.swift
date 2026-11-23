import SwiftUI

/// Picks the app's layout by width. Compact (iPhone, narrow iPad) is the tab
/// bar. Regular (iPad) is a sidebar beside the selected tab. This is the only
/// place in `App` that reads the size class for layout.
///
/// `tabContent` returns one navigation stack per tab. Both layouts keep those
/// stacks alive, so a pushed page survives a switch between tabs.
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
            // A bar-less TabView keeps every tab's stack alive. Only the
            // selected tab is shown and reachable by VoiceOver.
            TabView(selection: tabSelection) {
                ForEach(AppTab.allCases) { tab in
                    Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                        tabContent(tab)
                            .toolbarVisibility(.hidden, for: .tabBar)
                    }
                }
            }
            .toolbarVisibility(.hidden, for: .tabBar)
        }
    }
}
