import SwiftData
import SwiftUI

@main
struct HugoApp: App {
    @State private var loader = ModelContainerLoader(makeContainer: HugoApp.makeContainer)

    var body: some Scene {
        WindowGroup {
            switch loader.state {
            case .loaded(let container):
                AppRootView(settingsSync: Self.isRunningTests ? nil : SettingsSyncService())
                    .tint(.primary)
                    .toggleStyle(HugoToggleStyle())
                    .modelContainer(container)
            case .failed(let details):
                StoreLoadFailureView(report: .current(errorDetails: details), retry: loader.retry)
                    .tint(.primary)
            }
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        if ProcessInfo.processInfo.arguments.contains("-HugoSimulateStoreLoadFailure") {
            throw SimulatedStoreLoadFailure()
        }
        guard isRunningTests else { return try ModelContainerFactory.makeProductionContainer() }
        let container = try ModelContainerFactory.makeInMemoryContainer()
        if UITestSeed.isRequested() {
            try UITestSeed.insert(into: container.mainContext)
        }
        return container
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["HUGO_TEST_MODE"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
