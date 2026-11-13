import SwiftData
import SwiftUI

@main
struct HugoApp: App {
    @State private var loader = ModelContainerLoader(makeContainer: HugoApp.makeContainer)

    var body: some Scene {
        WindowGroup {
            switch loader.state {
            case .loaded(let container):
                AppRootView()
                    .tint(.primary)
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
        return
            try isRunningTests
            ? ModelContainerFactory.makeInMemoryContainer()
            : ModelContainerFactory.makeProductionContainer()
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["HUGO_TEST_MODE"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
