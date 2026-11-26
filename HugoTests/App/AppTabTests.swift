import Testing

@testable import Hugo

@MainActor
struct AppTabTests {
    @Test
    func tabDigitsFollowTabBarOrder() {
        #expect(AppTab.overview.commandDigit == "1")
        #expect(AppTab.planner.commandDigit == "2")
        #expect(AppTab.year.commandDigit == "3")
        #expect(AppTab.settings.commandDigit == nil)
    }

    @Test
    func digitsAreUnique() {
        let digits = AppTab.allCases.compactMap(\.commandDigit)
        #expect(Set(digits).count == digits.count)
    }

    @Test
    func todayCommandOnlyOnPagedTabs() {
        #expect(AppTab.planner.showsTodayCommand)
        #expect(AppTab.year.showsTodayCommand)
        #expect(!AppTab.overview.showsTodayCommand)
        #expect(!AppTab.settings.showsTodayCommand)
    }
}
