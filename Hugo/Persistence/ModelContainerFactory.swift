import Foundation
import OSLog
import SwiftData

@MainActor
enum ModelContainerFactory {
    private static let logger = Logger(subsystem: "com.ordellnielsen.Hugo", category: "Persistence")

    static func makeProductionContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: [configuration])
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
