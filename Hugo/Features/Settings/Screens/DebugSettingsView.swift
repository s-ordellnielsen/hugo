import SwiftData
import SwiftUI
import UIKit

#if SHOW_DEBUG_MENU
    struct DebugSettingsView: View {
        @AppStorage(UserDefaultsKeys.isOnboarding) var isOnboarding: Bool = true
        @Environment(\.modelContext) private var modelContext
        @State private var didCopyDiagnostics = false

        var body: some View {
            List {
                Button("debug.action.reset-onboarding", systemImage: "arrow.counterclockwise") {
                    isOnboarding = true
                }

                Section {
                    Button(copyTitle, systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc") {
                        Task { await copyDiagnostics() }
                    }
                } footer: {
                    Text("debug.action.copy-diagnostics.description")
                }
            }
            .navigationTitle("debug.title")
            .sensoryFeedback(.success, trigger: didCopyDiagnostics)
        }

        private var copyTitle: LocalizedStringKey {
            didCopyDiagnostics ? "debug.action.copy-diagnostics.done" : "debug.action.copy-diagnostics"
        }

        private func copyDiagnostics() async {
            let report = await DiagnosticsCollector(modelContext: modelContext).collect()
            UIPasteboard.general.string = report.text
            didCopyDiagnostics = true
        }
    }

    #Preview {
        NavigationStack {
            DebugSettingsView()
        }
        .modelContainer(.preview)
    }
#endif
