import SwiftUI

struct CardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}
