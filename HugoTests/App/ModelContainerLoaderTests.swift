import Foundation
import SwiftData
import Testing

@testable import Hugo

private struct StubError: Error, CustomStringConvertible {
    var description: String { "StubError(boom)" }
}

@MainActor
private final class StubContainerFactory {
    var failuresLeft: Int
    private(set) var callCount = 0

    init(failuresLeft: Int) {
        self.failuresLeft = failuresLeft
    }

    func make() throws -> ModelContainer {
        callCount += 1
        if failuresLeft > 0 {
            failuresLeft -= 1
            throw StubError()
        }
        return try InMemoryModelContainer.make()
    }
}

@MainActor
struct ModelContainerLoaderTests {
    @Test
    func loadsWhenFactorySucceeds() throws {
        let factory = StubContainerFactory(failuresLeft: 0)
        let loader = ModelContainerLoader(makeContainer: { try factory.make() })

        guard case .loaded = loader.state else {
            Issue.record("Expected .loaded, got \(loader.state)")
            return
        }
    }

    @Test
    func reportsFailureWithErrorDetails() {
        let factory = StubContainerFactory(failuresLeft: 1)
        let loader = ModelContainerLoader(makeContainer: { try factory.make() })

        guard case .failed(let details) = loader.state else {
            Issue.record("Expected .failed, got \(loader.state)")
            return
        }
        #expect(details.contains("StubError"))
    }

    @Test
    func retryAfterFailureLoadsWhenFactoryRecovers() {
        let factory = StubContainerFactory(failuresLeft: 1)
        let loader = ModelContainerLoader(makeContainer: { try factory.make() })

        loader.retry()

        guard case .loaded = loader.state else {
            Issue.record("Expected .loaded after retry, got \(loader.state)")
            return
        }
        #expect(factory.callCount == 2)
    }

    @Test
    func retryWhileLoadedDoesNotCallFactoryAgain() {
        let factory = StubContainerFactory(failuresLeft: 0)
        let loader = ModelContainerLoader(makeContainer: { try factory.make() })

        loader.retry()

        #expect(factory.callCount == 1)
    }

    @Test
    func corruptStoreFileFailsToOpenInsteadOfCrashing() throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        try Data("not a database".utf8).write(to: store.storeURL)

        let loader = ModelContainerLoader(makeContainer: {
            let schema = Schema(versionedSchema: CurrentSchema.self)
            let configuration = ModelConfiguration(
                schema: schema,
                url: store.storeURL,
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: MigrationPlan.self,
                configurations: [configuration]
            )
        })

        guard case .failed = loader.state else {
            Issue.record("Expected .failed for a corrupt store, got \(loader.state)")
            return
        }
    }
}
