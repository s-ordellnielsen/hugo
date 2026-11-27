import Foundation
import OSLog
import SwiftData

@MainActor
enum ModelContainerFactory {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Persistence")

    /// Opens the store in the App Group when the relocator says so, copying it from the legacy location first.
    ///
    /// The copy is trusted only after it is verified and the container opens and answers a fetch. The marker is written last.
    /// The legacy store is deleted only in a launch that started with the marker at `copied`.
    static func makeProductionContainer(
        relocator: StoreRelocator = StoreRelocator(
            legacyStoreURL: StoreRelocator.productionLegacyStoreURL(),
            groupDirectory: StoreRelocator.productionGroupDirectory()),
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .automatic
    ) throws -> ModelContainer {
        let resolution = relocator.resolve()
        if resolution.location == .legacy {
            return try openContainer(at: resolution.storeURL, cloudKitDatabase: cloudKitDatabase)
        }

        do {
            let container = try openAndProbe(at: resolution.storeURL, cloudKitDatabase: cloudKitDatabase)
            if resolution.isFreshCopy {
                relocator.markCopied()
            } else if resolution.legacyCleanupPending {
                relocator.confirmAndDeleteLegacyStore()
            } else {
                relocator.markFreshInstallIfNeeded()
            }
            return container
        } catch {
            guard resolution.isFreshCopy else { throw error }
            logger.error(
                "The copied store did not open, using the legacy store: \(error.localizedDescription, privacy: .public)"
            )
            relocator.abandonCopy()
            return try openContainer(at: relocator.legacyStoreURL, cloudKitDatabase: cloudKitDatabase)
        }
    }

    private static func openContainer(at url: URL, cloudKitDatabase: ModelConfiguration.CloudKitDatabase) throws
        -> ModelContainer
    {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: cloudKitDatabase)
        return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
    }

    private static func openAndProbe(at url: URL, cloudKitDatabase: ModelConfiguration.CloudKitDatabase) throws
        -> ModelContainer
    {
        let container = try openContainer(at: url, cloudKitDatabase: cloudKitDatabase)
        _ = try ModelContext(container).fetchCount(FetchDescriptor<Tracker>())
        return container
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
        } catch {
            logger.error("Could not create in-memory model container: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
