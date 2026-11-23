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
        rule.selectionSwitched()
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

    @Test func repeatedPressBeganDuringOneTapKeepsTheStartingSelection() {
        var rule = SidebarTapRule()

        // Touch-down with Overview selected, then the selection switches to Year
        // while the finger is still down, then the next move reports the press.
        rule.pressBegan(on: .year, selected: .overview)
        rule.selectionSwitched()
        rule.pressBegan(on: .year, selected: .year)
        rule.pressBegan(on: .year, selected: .year)

        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }

    @Test func switchBeforeTheFirstPressBeganDoesNotPop() {
        var rule = SidebarTapRule()

        // The selection changed before the first onChanged of this tap.
        rule.selectionSwitched()
        rule.pressBegan(on: .year, selected: .year)

        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }

    @Test func switchAfterPressBeganDoesNotPop() {
        var rule = SidebarTapRule()

        rule.pressBegan(on: .year, selected: .overview)
        rule.selectionSwitched()

        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }

    @Test func plainReselectAfterAPressThatSwitchedStillPops() {
        var rule = SidebarTapRule()

        rule.pressBegan(on: .year, selected: .overview)
        rule.selectionSwitched()
        #expect(rule.tapEnded(on: .year, travel: 0) == nil)

        // The next tap on the now selected Year row is a real reselect.
        rule.pressBegan(on: .year, selected: .year)
        #expect(rule.tapEnded(on: .year, travel: 0) == .year)
    }

    @Test func staleSwitchWithNoPressDoesNotSwallowALaterReselect() {
        var rule = SidebarTapRule()

        // A completed press, then a switch with no press open (a keyboard
        // switch that never reached a gesture end).
        rule.pressBegan(on: .settings, selected: .settings)
        #expect(rule.tapEnded(on: .settings, travel: 0) == .settings)
        rule.selectionSwitched()

        // The next press on the selected Year row must still reselect.
        rule.pressBegan(on: .year, selected: .year)
        #expect(rule.tapEnded(on: .year, travel: 0) == .year)
    }

    @Test func switchWithNoPressBeforeAnyPressStillCountsForTheNextPress() {
        var rule = SidebarTapRule()

        // Nothing has been pressed yet, so the switch belongs to the next tap.
        rule.selectionSwitched()
        rule.pressBegan(on: .year, selected: .year)

        #expect(rule.tapEnded(on: .year, travel: 0) == nil)
    }
}
