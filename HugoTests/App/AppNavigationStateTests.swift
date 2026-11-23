import SwiftUI
import Testing

@testable import Hugo

@MainActor
struct AppNavigationStateTests {
    @Test func switchingTabsKeepsPaths() {
        let navigation = AppNavigationState()
        navigation.settingsPath.append("settings-page")
        navigation.yearPath.append("year-page")

        navigation.select(.overview)
        navigation.select(.settings)

        #expect(navigation.settingsPath.count == 1)
        #expect(navigation.yearPath.count == 1)
    }

    @Test func reselectClearsThatTabsPath() {
        let navigation = AppNavigationState()
        navigation.select(.year)
        navigation.yearPath.append("year-page")
        navigation.settingsPath.append("settings-page")

        navigation.select(.year)

        #expect(navigation.yearPath.isEmpty)
        #expect(navigation.settingsPath.count == 1)
    }

    @Test func reselectChangesResetTokenOnlyOnReselect() {
        let navigation = AppNavigationState()

        let yearToken = navigation.yearResetToken
        navigation.select(.year)
        #expect(navigation.yearResetToken == yearToken)
        navigation.select(.year)
        #expect(navigation.yearResetToken != yearToken)

        let plannerToken = navigation.plannerResetToken
        navigation.select(.planner)
        #expect(navigation.plannerResetToken == plannerToken)
        navigation.select(.planner)
        #expect(navigation.plannerResetToken != plannerToken)
    }

    @Test func reselectOverviewDoesNothing() {
        let navigation = AppNavigationState()
        navigation.settingsPath.append("settings-page")

        navigation.select(.overview)
        navigation.select(.overview)

        #expect(navigation.selectedTab == .overview)
        #expect(navigation.settingsPath.count == 1)
    }

    @Test func compactMovesSettingsToOverviewAndKeepsItsPath() {
        let navigation = AppNavigationState(selectedTab: .settings)
        navigation.settingsPath.append("settings-page")

        navigation.ensureSelectionVisible(compact: true)

        #expect(navigation.selectedTab == .overview)
        #expect(navigation.settingsPath.count == 1)
    }
}
