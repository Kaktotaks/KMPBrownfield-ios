import SwiftUI

/// M5: scale 1 -> 0.96 while pressed, 100 ms ease-out.
struct TKPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.easeOut(Motion.press), value: configuration.isPressed)
    }
}
