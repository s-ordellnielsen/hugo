import SwiftData
import SwiftUI

@main
struct HugoApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer =
                try Self.isRunningTests
                ? ModelContainerFactory.makeInMemoryContainer()
                : ModelContainerFactory.makeProductionContainer()
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["HUGO_TEST_MODE"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(.primary)
                .modelContainer(modelContainer)
        }
    }
}
