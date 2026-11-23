import SwiftUI

/// Which tab is selected and where each tab's stack is. Owned by `AppRootView`
/// as `@State`, so no layout change rebuilds it.
@Observable
@MainActor
final class AppNavigationState {
    var selectedTab: AppTab
    var yearPath = NavigationPath()
    var settingsPath = NavigationPath()
    private(set) var yearResetToken = UUID()
    private(set) var plannerResetToken = UUID()
    /// The Service Year page and the Planner month the person is on. The
    /// views read them when they appear again, so the page survives a switch.
    var displayedYear: TheocraticYear?
    var displayedMonth: YearMonth?

    init(selectedTab: AppTab = .overview) {
        self.selectedTab = selectedTab
    }

    /// A different tab keeps every stack as it is. The selected tab again goes to its root.
    func select(_ tab: AppTab) {
        guard tab == selectedTab else {
            selectedTab = tab
            return
        }
        popToRoot(tab)
    }

    func popToRoot(_ tab: AppTab) {
        switch tab {
        case .overview:
            break
        case .planner:
            plannerResetToken = UUID()
        case .year:
            yearPath = NavigationPath()
            yearResetToken = UUID()
        case .settings:
            settingsPath = NavigationPath()
        }
    }

    /// Settings has no tab at compact width. Moves the selection, keeps the path.
    func ensureSelectionVisible(compact: Bool) {
        if !selectedTab.placement.isVisible(compact: compact) {
            selectedTab = .overview
        }
    }
}
