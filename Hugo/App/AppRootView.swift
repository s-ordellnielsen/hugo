import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("isOnboarding") private var needsOnboarding = true
    @State private var bootstrapper = AppBootstrapper()

    var body: some View {
        TabView {
            Tab("tab.overview", systemImage: "house") { OverviewView() }
            Tab("tab.report", systemImage: "tray.full.fill") { ReportsView() }
        }
        .task { await bootstrapper.start(context: context) }
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
        .alert("common.error", isPresented: Binding(get: { bootstrapper.state == .failed }, set: { _ in })) {
            Button("common.retry") { Task { await bootstrapper.retry(context: context) } }
        } message: { Text(bootstrapper.errorMessage ?? "common.error") }
    }
}
