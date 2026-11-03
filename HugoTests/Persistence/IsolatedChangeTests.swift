import SwiftData
import Testing

@testable import Hugo

@MainActor
struct IsolatedChangeTests {
    private struct TestError: Error {}

    @Test
    func failedChangeKeepsEarlierPendingEdits() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let tracker = Tracker(name: "A")
        context.insert(tracker)
        try context.save()

        tracker.name = "B"

        #expect(throws: TestError.self) {
            try context.performIsolatedChange {
                context.insert(Tracker(name: "C"))
                throw TestError()
            }
        }

        #expect(tracker.name == "B")
        #expect(!context.hasChanges)
        let names = try context.fetch(FetchDescriptor<Tracker>()).map(\.name)
        #expect(names == ["B"])
    }

    @Test
    func successfulChangeIsSaved() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext

        try context.performIsolatedChange { context.insert(Tracker(name: "C")) }

        #expect(!context.hasChanges)
        let names = try context.fetch(FetchDescriptor<Tracker>()).map(\.name)
        #expect(names.contains("C"))
    }
}
