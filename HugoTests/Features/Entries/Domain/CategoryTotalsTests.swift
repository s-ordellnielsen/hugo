import Foundation
import Testing

@testable import Hugo

struct CategoryTotalsTests {
    private let locale = Locale(identifier: "en_US_POSIX")
    private let day = Date(timeIntervalSince1970: 1_780_000_000)

    @Test
    func liveEntriesGroupByCategory() {
        let first = Tracker(name: "Field Service", type: .main, iconName: "figure.walk")
        let second = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [
            entry(600, tracker: first), entry(300, tracker: first), entry(900, tracker: second),
        ]
        let rows = CategoryTotals.rows(entries: entries, locale: locale)

        #expect(rows.count == 2)
        #expect(rows.map(\.duration) == [900, 900])
        #expect(Set(rows.compactMap(\.trackerID)) == [first.id, second.id])
        #expect(rows.first { $0.trackerID == first.id }?.duration == 900)
    }

    @Test
    func snapshotJoinsTheLiveCategoryWithTheSameNameAndType() {
        let bethel = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let copy = entry(600, copy: ("Bethel", "building", .separate))
        let rows = CategoryTotals.rows(entries: [copy], trackers: [bethel], locale: locale)

        #expect(rows.count == 1)
        #expect(rows.first?.trackerID == bethel.id)
        #expect(rows.first?.duration == 600)
    }

    @Test
    func snapshotJoinsACategoryFoundOnAnotherEntry() {
        let bethel = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [
            entry(600, copy: ("Bethel", "building", .separate)),
            entry(300, tracker: bethel),
        ]
        let rows = CategoryTotals.rows(entries: entries, trackers: [], locale: locale)

        #expect(rows.count == 1)
        #expect(rows.first?.trackerID == bethel.id)
        #expect(rows.first?.duration == 900)
    }

    @Test
    func carriedMainTimeJoinsTheDefaultCategoryWhateverItsName() {
        let field = Tracker(name: "Forkyndelse", type: .main, isDefault: true, iconName: "figure.walk")
        let entries = [
            entry(3_600, tracker: field),
            entry(1_800, copy: ("Tjeneste", "figure.walk", .main), carried: true),
        ]
        let rows = CategoryTotals.rows(entries: entries, trackers: [field], locale: locale)

        #expect(rows.count == 1)
        #expect(rows.first?.name == "Forkyndelse")
        #expect(rows.first?.duration == 5_400)
    }

    @Test
    func carriedMainTimeWithoutADefaultKeepsItsOwnRow() {
        let other = Tracker(name: "Other", type: .main, iconName: "tag")
        let entries = [entry(1_800, copy: ("Tjeneste", "figure.walk", .main), carried: true)]
        let rows = CategoryTotals.rows(entries: entries, trackers: [other], locale: locale)

        #expect(rows.count == 1)
        #expect(rows.first?.id == "stored:Tjeneste|figure.walk|main")
        #expect(rows.first?.trackerID == nil)
    }

    @Test
    func snapshotThatIsNotCarriedDoesNotJoinTheDefaultByType() {
        let field = Tracker(name: "Field Service", type: .main, isDefault: true, iconName: "figure.walk")
        let entries = [
            entry(3_600, tracker: field),
            entry(600, copy: ("Old", "tag", .main)),
        ]
        let rows = CategoryTotals.rows(entries: entries, trackers: [field], locale: locale)

        #expect(rows.count == 2)
    }

    @Test
    func snapshotWithDifferentTypeDoesNotMerge() {
        let live = Tracker(name: "Bethel", type: .main, iconName: "building")
        let entries = [
            entry(3_600, tracker: live),
            entry(600, copy: ("Bethel", "building", .separate)),
        ]
        let rows = CategoryTotals.rows(entries: entries, trackers: [live], locale: locale)

        #expect(rows.count == 2)
    }

    @Test
    func twoLiveCategoriesWithTheSameNameStaySeparate() {
        let first = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let second = Tracker(name: "Bethel", type: .separate, iconName: "building")
        let entries = [entry(600, tracker: first), entry(600, tracker: second)]
        let rows = CategoryTotals.rows(entries: entries, trackers: [first, second], locale: locale)

        #expect(rows.count == 2)
    }

    @Test
    func untrackedTimeHasItsOwnRow() {
        let rows = CategoryTotals.rows(entries: [entry(600)], locale: locale)

        #expect(rows.count == 1)
        #expect(rows.first?.id == "untracked")
        #expect(rows.first?.type == nil)
    }

    @Test
    func rowsAreSortedByDurationThenName() {
        let alpha = Tracker(name: "Alpha", type: .separate, iconName: "a.circle")
        let beta = Tracker(name: "Beta", type: .separate, iconName: "b.circle")
        let gamma = Tracker(name: "Gamma", type: .separate, iconName: "g.circle")
        let entries = [
            entry(600, tracker: beta), entry(600, tracker: alpha), entry(1_200, tracker: gamma),
        ]
        let rows = CategoryTotals.rows(entries: entries, locale: locale)

        #expect(rows.map(\.name) == ["Gamma", "Alpha", "Beta"])
    }

    private func entry(
        _ duration: TimeInterval, tracker: Tracker? = nil, copy: (String, String, TrackerType)? = nil,
        carried: Bool = false
    ) -> Entry {
        let entry = Entry(date: day, duration: duration, tracker: tracker)
        if let copy {
            entry.storedTracker = Entry.EntryTracker(name: copy.0, icon: copy.1, type: copy.2)
        }
        if carried {
            entry.sourceReportYear = 2026
            entry.sourceReportMonth = 5
        }
        return entry
    }
}
