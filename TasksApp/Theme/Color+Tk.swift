import SwiftUI

/// Design tokens, color (DESIGN_HANDOFF §1.1). Asset-catalog color sets with Any/Dark appearances
/// (`Assets.xcassets/TK`), same token names as Android `TasksColors`. Use `Color.tk.<name>`; no hex literals in views.
struct TKColors {
    let bg = Color("TK/bg")
    let surface = Color("TK/surface")
    let surface2 = Color("TK/surface2")
    let border = Color("TK/border")
    let outline = Color("TK/outline")
    let textPrimary = Color("TK/textPrimary")
    let textSecondary = Color("TK/textSecondary")
    let textTertiary = Color("TK/textTertiary")
    let inverse = Color("TK/inverse")
    let onInverse = Color("TK/onInverse")
    let accent = Color("TK/accent")
    let onAccent = Color("TK/onAccent")
    let onAccentMuted = Color("TK/onAccentMuted")
    let danger = Color("TK/danger")
    let dangerContainer = Color("TK/dangerContainer")
    let onDangerContainer = Color("TK/onDangerContainer")
    let priorityHigh = Color("TK/priorityHigh")
    let onPriorityHigh = Color("TK/onPriorityHigh")
    let priorityMedium = Color("TK/priorityMedium")
    let onPriorityMedium = Color("TK/onPriorityMedium")
    let priorityLow = Color("TK/priorityLow")
    let onPriorityLow = Color("TK/onPriorityLow")
    let heroBg = Color("TK/heroBg")
    let heroText = Color("TK/heroText")
    let heroTextSecondary = Color("TK/heroTextSecondary")
    let ringTrack = Color("TK/ringTrack")
    let scrim = Color("TK/scrim")
    /// Voice notes: unplayed waveform bars (#E2E2DA light / #3A3A36 dark). Played bars = `textPrimary`, recording dot = `danger`.
    let waveformTrack = Color("TK/waveformTrack")
}

extension Color {
    static let tk = TKColors()
}
