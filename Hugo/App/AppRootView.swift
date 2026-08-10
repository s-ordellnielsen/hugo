import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("isOnboarding") private var needsOnboarding = true

    @State private var bootstrapper = AppBootstrapper()
    @State private var selectedTab: AppTab = .overview
    @State private var yearResetToken = UUID()
    @State private var bootstrapErrorMessage: String?

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
        .tabViewStyle(.sidebarAdaptable)
        .task { await bootstrapper.start(context: context) }
        .sheet(isPresented: $needsOnboarding) { OnboardingView { needsOnboarding = false } }
        .onChange(of: bootstrapper.errorMessage) { _, newValue in bootstrapErrorMessage = newValue }
        .errorAlert(message: $bootstrapErrorMessage, retry: { Task { await bootstrapper.retry(context: context) } })
    }
}

enum AppTab: Hashable {
    case overview, year
}
