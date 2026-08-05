import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("isOnboarding") private var needsOnboarding = true

    @State private var bootstrapper = AppBootstrapper()
    @State private var selectedTab: AppTab = .overview
    @State private var yearResetToken = UUID()

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .year && selectedTab == .year {
                    yearResetToken = UUID()
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("tab.overview", systemImage: "house", value: AppTab.overview) {
                OverviewView()
            }
            Tab("tab.year", systemImage: "tray.full.fill", value: AppTab.year) {
                ServiceYearView(resetToken: yearResetToken)
            }
        }
        .task { await bootstrapper.start(context: context) }
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
        .alert("common.error", isPresented: Binding(get: { bootstrapper.state == .failed }, set: { _ in })) {
            Button("common.retry") { Task { await bootstrapper.retry(context: context) } }
        } message: {
            Text(bootstrapper.errorMessage ?? "common.error")
        }
    }
}

enum AppTab: Hashable {
    case overview, year
}
