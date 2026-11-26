import SwiftUI

/// What the menu bar can ask the focused window to do. `AppRootView` publishes
/// it with `focusedSceneValue`.
struct AppCommandActions {
    var selectedTab: AppTab
    var addEntry: () -> Void
    var select: (AppTab) -> Void
    var showToday: () -> Void
    var showSettings: () -> Void
}

extension FocusedValues {
    @Entry var appCommands: AppCommandActions?
}

/// Hugo's menu bar items on iPad (and keyboard shortcuts on any device with a keyboard).
struct HugoCommands: Commands {
    @FocusedValue(\.appCommands) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("entry.add.label") { actions?.addEntry() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("settings.title") { actions?.showSettings() }
                .keyboardShortcut(",")
                .disabled(actions == nil)
        }
        CommandGroup(before: .sidebar) {
            ForEach(AppTab.allCases.filter { $0.commandDigit != nil }) { tab in
                if let digit = tab.commandDigit {
                    Button(tab.titleKey) { actions?.select(tab) }
                        .keyboardShortcut(KeyEquivalent(digit))
                        .disabled(actions == nil)
                }
            }
            Button("commands.today") { actions?.showToday() }
                .keyboardShortcut("t")
                .disabled(!(actions?.selectedTab.showsTodayCommand ?? false))
            Divider()
        }
    }
}
