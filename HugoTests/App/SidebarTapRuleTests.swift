import Testing

@testable import Hugo

struct SidebarTapRuleTests {
    @Test func tapOnAnotherRowSwitchesAndNeverPops() {
        var rule = SidebarTapRule()

        rule.pressBegan(on: .year, selected: .overview)

        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }

    @Test func tapOnTheSelectedRowReselectsOnce() {
        var rule = SidebarTapRule()

        rule.pressBegan(on: .year, selected: .year)

        #expect(rule.tapEnded(on: .year, travel: 0) == .year)
        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }

    @Test func selectionChangedDuringTheTapDoesNotHideAReselectOrCauseOne() {
        var rule = SidebarTapRule()

        // The selection set to the tab it already has, before the tap ends.
        rule.pressBegan(on: .planner, selected: .planner)
        #expect(rule.tapEnded(on: .planner, travel: 0) == .planner)

        // A switch whose selection change ran before the tap ended pops nothing.
        rule.pressBegan(on: .year, selected: .overview)
        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }

    @Test func movedTouchOnTheSelectedRowIsAScrollNotAReselect() {
        var rule = SidebarTapRule()

        rule.pressBegan(on: .year, selected: .year)

        #expect(rule.tapEnded(on: .year, travel: 40) == nil)
    }

    @Test func cancelledPressDoesNotSwallowALaterReselect() {
        var rule = SidebarTapRule()

        // A press that never ended, on another row.
        rule.pressBegan(on: .overview, selected: .year)

        // A later real reselect of the Year row.
        rule.pressBegan(on: .year, selected: .year)
        #expect(rule.tapEnded(on: .year, travel: 0) == .year)
    }

    @Test func tapWithoutAPressDoesNothing() {
        var rule = SidebarTapRule()

        #expect(rule.tapEnded(on: .settings, travel: 0) == nil)
    }
}
