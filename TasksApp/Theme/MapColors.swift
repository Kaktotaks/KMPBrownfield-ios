import SwiftUI
import UIKit
import Shared

/// Colours that only the Map feature needs (pin / marker / sheet details of `design-handoff/map/components`).
/// Everything else uses `Color.tk.*`. Light / dark pairs live here so views carry no hex literals.
enum MapColors {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }

    /// Ring around pins and the order badge (white / black).
    static let pinRing = dynamic(0xFFFFFF, 0x000000)
    /// Start marker: black disc, lime glyph; ring white / #3A3A36.
    static let startDisc = Color(uiColor: UIColor(rgb: 0x0A0A0A))
    static let startRing = dynamic(0xFFFFFF, 0x3A3A36)
    static let startLabelBorder = dynamic(0x0A0A0A, 0x3A3A36)
    static let startLabelText = Color.white
    /// Done pin head + glyph.
    static let doneHead = dynamic(0xEBEBE4, 0x232323)
    static let doneGlyph = dynamic(0x6E6E68, 0x8A8A84)
    static let doneOrderBadge = dynamic(0x8C8C85, 0x3A3A36)
    /// Order badge (black on light, white on dark) and its text.
    static let orderBadge = dynamic(0x0A0A0A, 0xFFFFFF)
    static let onOrderBadge = dynamic(0xFFFFFF, 0x0A0A0A)
    /// Sheet grabber.
    static let grabber = dynamic(0xC9C9C1, 0x4A4A46)
    /// Move ghost fill.
    static let ghostFill = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.06) : UIColor(rgb: 0x0A0A0A, alpha: 0.04) })
    /// Move banner (always black surface).
    static let bannerSurface = Color(uiColor: UIColor(rgb: 0x0A0A0A))
    static let bannerButton = Color(uiColor: UIColor(rgb: 0x232323))
    static let bannerBorder = dynamic(0x0A0A0A, 0x3A3A36)

    /// Tinted ("past") priority badge: container, text, border (readable, ≥ 4.5:1).
    static func fadedBadge(_ priority: Priority) -> (fill: Color, text: Color, border: Color) {
        switch priority {
        case .high: return (dynamic(0xFDE8E6, 0x3A1512), dynamic(0xB42323, 0xFFB4AD), dynamic(0xF4C2BD, 0x6B2A24))
        case .medium: return (dynamic(0xFFF1D6, 0x33280F), dynamic(0x7A5200, 0xFFD58A), dynamic(0xF2D9A6, 0x5C4613))
        case .low: return (dynamic(0xF2F2EC, 0x1C1C1A), dynamic(0x4F4F4A, 0xB3B3AD), dynamic(0xE2E2DA, 0x3A3A36))
        }
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// "#RRGGBB" from the shared route / map palettes.
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        self.init(rgb: UInt32(value & 0xFFFFFF))
    }
}

extension MapColors {
    /// Route sheet: vertical connector between stop badges.
    static let connector = dynamic(0xE2E2DA, 0x3A3A36)
}
