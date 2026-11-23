import Foundation

/// Decides whether one tap on an iPad sidebar row reselects its tab, which pops
/// that tab to its root. The selection only switches tabs, so reselect has to be
/// decided from the selection that was current when the press began. Recording
/// that at touch-down makes the outcome the same whichever runs first, the
/// selection change or the tap.
///
/// A press can change the selection while the finger is still down. The
/// selection binding reports that with `selectionSwitched()`, and the press then
/// never counts as a reselect. The flag is cleared when the next press begins
/// after a press has already been seen, so a switch made with no press open
/// (a keyboard switch, say) cannot swallow the reselect that follows it.
nonisolated struct SidebarTapRule: Sendable {
    /// A touch that travels farther than this is a scroll, not a tap.
    static let tapTolerance: Double = 10

    private var pressedTab: AppTab?
    private var selectedAtPress: AppTab?
    private var switched = false
    /// True once any press has begun or ended. Decides whether a new press
    /// starts with a clean `switched` flag.
    private var hasSeenPress = false

    /// Call on every touch-down and touch-move, with the selection as it is now.
    /// Only the first call of a press records anything, so a selection change
    /// during the press cannot overwrite the selection the press started from.
    /// A call for a different tab starts a new press, which means the earlier
    /// press never ended.
    mutating func pressBegan(on tab: AppTab, selected: AppTab) {
        if pressedTab == tab { return }
        if hasSeenPress { switched = false }
        hasSeenPress = true
        pressedTab = tab
        selectedAtPress = selected
    }

    /// Call from the selection binding when it switches to another tab. Marks
    /// the current press, or the next one if no press is open yet.
    mutating func selectionSwitched() {
        switched = true
    }

    /// Call when the touch ends. Returns the tab to pop to its root when the
    /// touch was a tap on a tab that was already selected and no switch
    /// happened during it, otherwise nil. Always clears the press.
    mutating func tapEnded(on tab: AppTab, travel: Double) -> AppTab? {
        let isReselect =
            pressedTab == tab
            && selectedAtPress == tab
            && travel <= Self.tapTolerance
            && !switched
        pressedTab = nil
        selectedAtPress = nil
        switched = false
        hasSeenPress = true
        return isReselect ? tab : nil
    }
}
