import SwiftData
import SwiftUI

@main
struct HugoApp: App {
    let modelContainer: ModelContainer

    init() {
        do { modelContainer = try ModelContainerFactory.makeProductionContainer() } catch {
            fatalError("Could not create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { AppRootView() }.modelContainer(modelContainer)
    }
}
