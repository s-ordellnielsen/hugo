import Foundation
import Testing

@testable import Hugo

@MainActor
struct EntryCategoryTests {
    @Test
    func liveTrackerWins() {
        let tracker = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entry = Entry(date: .now, duration: 1_800, tracker: tracker)
        let category = entry.resolvedCategory()
        #expect(category.key == tracker.id.uuidString)
        #expect(category.name == "Bethel")
        #expect(category.type == .separate)
        #expect(category.trackerID == tracker.id)
    }

    @Test
    func snapshotIsUsedWithoutTracker() {
        let entry = Entry(date: .now, duration: 1_800, tracker: nil)
        entry.storedTracker = Entry.EntryTracker(name: "Bethel", icon: "building", type: .separate)
        let category = entry.resolvedCategory()
        #expect(category.key == "stored:Bethel|building|separate")
        #expect(category.name == "Bethel")
        #expect(category.iconName == "building")
        #expect(category.type == .separate)
        #expect(category.trackerID == nil)
    }

    @Test
    func untrackedFallback() {
        let entry = Entry(date: .now, duration: 1_800, tracker: nil)
        let category = entry.resolvedCategory()
        #expect(category.key == "untracked")
        #expect(category.type == nil)
        #expect(category.iconName == "questionmark.circle")
        #expect(category.name == String(localized: "entry.untracked"))
    }

    @Test
    func refreshCopiesCurrentTracker() {
        let entry = Entry(date: .now, duration: 1_800, tracker: Tracker(name: "Bethel", type: .separate))
        entry.tracker = Tracker(name: "Field Service", type: .main)
        entry.refreshStoredTracker()
        #expect(entry.storedTracker?.name == "Field Service")
        #expect(entry.storedTracker?.type == .main)
    }
}
