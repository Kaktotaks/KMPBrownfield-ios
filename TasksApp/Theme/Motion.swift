import SwiftUI

/// Motion tokens (DESIGN_HANDOFF §4). Durations in ms, one easing everywhere: `emphasized`.
/// Same values and names as Android `Motion`.
enum Motion {
    static let press = 100
    static let short = 150
    static let medium = 250
    static let long = 600
    static let extraLong = 900
    static let stagger = 80
    /// Skeleton pulse: one half-cycle (M7).
    static let pulseHalfCycle = 1000

    /// cubic-bezier(0.2, 0, 0, 1).
    static func emphasized(_ durationMs: Int, delayMs: Int = 0) -> Animation {
        .timingCurve(0.2, 0, 0, 1, duration: Double(durationMs) / 1000).delay(Double(delayMs) / 1000)
    }

    static func easeOut(_ durationMs: Int) -> Animation {
        .easeOut(duration: Double(durationMs) / 1000)
    }

    static func easeInOut(_ durationMs: Int) -> Animation {
        .easeInOut(duration: Double(durationMs) / 1000)
    }
}

extension View {
    /// `.animation(...)` that snaps under Reduce Motion (§4.3).
    func tkAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(TKAnimationModifier(animation: animation, value: value))
    }
}

private struct TKAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
