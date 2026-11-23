import Foundation

/// Decides whether one tap on an iPad sidebar row reselects its tab, which pops
/// that tab to its root. The selection only switches tabs, so reselect has to be
/// decided from the selection that was current when the press began. Recording
/// that at touch-down makes the outcome the same whichever runs first, the
/// selection change or the tap.
nonisolated struct SidebarTapRule: Sendable {
    /// A touch that travels farther than this is a scroll, not a tap.
    static let tapTolerance: Double = 10

    private var pressedTab: AppTab?
    private var selectedAtPress: AppTab?

    /// Call on every touch-down and touch-move, with the selection as it is now.
    /// Selection only changes when a tap completes, so the last call before the
    /// end is the selection the tap started from.
    mutating func pressBegan(on tab: AppTab, selected: AppTab) {
        pressedTab = tab
        selectedAtPress = selected
    }

    /// Call when the touch ends. Returns the tab to pop to its root when the
    /// touch was a tap on a tab that was already selected, otherwise nil. Always
    /// clears the press, so a press that was cancelled cannot affect a later one.
    mutating func tapEnded(on tab: AppTab, travel: Double) -> AppTab? {
        defer {
            pressedTab = nil
            selectedAtPress = nil
        }
        guard pressedTab == tab, selectedAtPress == tab, travel <= Self.tapTolerance else {
            return nil
        }
        return tab
    }
}
