import SwiftUI

/// Radius tokens (DESIGN_HANDOFF §1.3). Same names and values as Android `Radius`.
enum Radius {
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

/// Spacing scale 4, 8, 12, 16, 20, 24, 32, 48 (same names as Android `Spacing`).
enum Spacing {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
    static let s48: CGFloat = 48

    /// Screen gutter.
    static let gutter = s16
    /// Gap between task cards.
    static let cardGap = s8
    /// Gap between sections.
    static let sectionGap = s12
    /// Minimum touch target (44 pt on iOS, 48 dp on Android).
    static let minTarget: CGFloat = 44
}
