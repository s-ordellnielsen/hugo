import SwiftUI

/// Draws every switch in the app's accent color. The app's root tint is
/// monochrome, so switches would otherwise be black or white.
struct HugoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: configuration.$isOn) { configuration.label }
            .toggleStyle(.switch)
            .tint(.hugoAccent)
    }
}
