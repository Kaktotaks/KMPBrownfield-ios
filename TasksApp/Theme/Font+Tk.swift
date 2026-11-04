import SwiftUI
import UIKit

/// Type scale (DESIGN_HANDOFF §1.2): same token names, sizes, line heights and tracking as Android `TasksType`.
/// Inter (400/500/600/700) and Inter Tight (800) are bundled (SIL OFL, `Fonts/OFL.txt`) and registered via UIAppFonts.
/// `Font.custom(name, size:, relativeTo:)` makes Dynamic Type scale them.
struct TKTextStyle {
    enum Face: String {
        case regular = "Inter-Regular"
        case medium = "Inter-Medium"
        case semibold = "Inter-SemiBold"
        case bold = "Inter-Bold"
        case tightExtraBold = "InterTight-ExtraBold"
    }

    let face: Face
    let size: CGFloat
    let lineHeight: CGFloat
    /// Tracking in em (iOS needs `.tracking(size * em)`).
    let tracking: CGFloat
    let relativeTo: Font.TextStyle
    var tabular = false
    var uppercase = false

    var font: Font { .custom(face.rawValue, size: size, relativeTo: relativeTo) }

    private init(_ face: Face, _ size: CGFloat, _ lineHeight: CGFloat, _ tracking: CGFloat = 0,
                 _ relativeTo: Font.TextStyle, tabular: Bool = false, uppercase: Bool = false) {
        self.face = face
        self.size = size
        self.lineHeight = lineHeight
        self.tracking = tracking
        self.relativeTo = relativeTo
        self.tabular = tabular
        self.uppercase = uppercase
    }

    static let largeTitle = TKTextStyle(.tightExtraBold, 34, 38, -0.03, .largeTitle)
    static let display = TKTextStyle(.tightExtraBold, 64, 64, -0.04, .largeTitle, tabular: true)
    static let statNumber = TKTextStyle(.tightExtraBold, 40, 44, -0.03, .title, tabular: true)
    static let heroTitle = TKTextStyle(.tightExtraBold, 30, 33, -0.03, .title)
    static let title = TKTextStyle(.tightExtraBold, 24, 28, -0.02, .title2)
    static let sheetTitle = TKTextStyle(.bold, 17, 22, 0, .headline)
    static let headline = TKTextStyle(.semibold, 17, 22, 0, .headline)
    static let body = TKTextStyle(.regular, 16, 24, 0, .body)
    static let button = TKTextStyle(.semibold, 16, 20, 0, .body)
    static let subhead = TKTextStyle(.medium, 14, 20, 0, .subheadline)
    static let caption = TKTextStyle(.medium, 13, 18, 0, .footnote)
    static let overline = TKTextStyle(.bold, 12, 16, 0.06, .caption, uppercase: true)
    static let badge = TKTextStyle(.bold, 11, 14, 0.04, .caption2, uppercase: true)

    // Variants the handoff names inline (§1.2 usage, §2 components); same names as Android.
    /// `body` 500: Cancel in the editor header, unselected segments.
    static let bodyMedium = TKTextStyle(.medium, 16, 24, 0, .body)
    /// `body` 600: info-row values.
    static let bodyStrong = TKTextStyle(.semibold, 16, 24, 0, .body)
    /// PriorityBar label ("body-15" 600).
    static let label15 = TKTextStyle(.semibold, 15, 20, 0, .body)
    /// "N tasks" / "N of M tasks done" ("subhead-15").
    static let subhead15 = TKTextStyle(.medium, 15, 20, 0, .subheadline)
    /// SavePill: Inter 700 15.
    static let savePill = TKTextStyle(.bold, 15, 20, 0, .body)
    /// Overdue due line: `subhead` weight 600.
    static let subheadStrong = TKTextStyle(.semibold, 14, 20, 0, .subheadline)
    /// Voice recorder timer: Inter Tight 800 48/52, tabular.
    static let recorderTimer = TKTextStyle(.tightExtraBold, 48, 52, -0.03, .largeTitle, tabular: true)
    /// Voice buttons (Re-record / Delete / Cancel / Stop): Inter 600 15.
    static let voiceButton = TKTextStyle(.semibold, 15, 20, 0, .body)
    /// Player elapsed time "0:12" (600) and "/ 0:42" (500), tabular.
    static let playerElapsed = TKTextStyle(.semibold, 15, 20, 0, .subheadline, tabular: true)
    static let playerTotal = TKTextStyle(.medium, 15, 20, 0, .subheadline, tabular: true)
    /// StatusBadge: `badge` at 12.
    static let statusBadge = TKTextStyle(.bold, 12, 14, 0.04, .caption, uppercase: true)
}

extension Font {
    /// `Font.tk.headline` etc. Fonts only; use `.tkStyle(_:)` to also get tracking, line height and tabular digits.
    static let tk = TKFonts()
}

struct TKFonts {
    var largeTitle: Font { TKTextStyle.largeTitle.font }
    var display: Font { TKTextStyle.display.font }
    var statNumber: Font { TKTextStyle.statNumber.font }
    var heroTitle: Font { TKTextStyle.heroTitle.font }
    var title: Font { TKTextStyle.title.font }
    var sheetTitle: Font { TKTextStyle.sheetTitle.font }
    var headline: Font { TKTextStyle.headline.font }
    var body: Font { TKTextStyle.body.font }
    var button: Font { TKTextStyle.button.font }
    var subhead: Font { TKTextStyle.subhead.font }
    var caption: Font { TKTextStyle.caption.font }
    var overline: Font { TKTextStyle.overline.font }
    var badge: Font { TKTextStyle.badge.font }
}

/// Applies a [TKTextStyle]: font (Dynamic Type), tracking and line height in em/pt scaled with the text size,
/// tabular digits for changing numbers (`monospacedDigit`).
private struct TKTextStyleModifier: ViewModifier {
    let style: TKTextStyle
    @ScaledMetric private var scale: CGFloat

    init(style: TKTextStyle) {
        self.style = style
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: style.relativeTo)
    }

    private var naturalLineHeight: CGFloat {
        (UIFont(name: style.face.rawValue, size: style.size)?.lineHeight ?? style.size * 1.21)
    }

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.size * style.tracking * scale)
            // Line height from the token: spacing = target - natural (both scale together).
            .lineSpacing((style.lineHeight - naturalLineHeight) * scale)
            .modifier(TabularDigits(enabled: style.tabular))
    }
}

private struct TabularDigits: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.monospacedDigit() } else { content }
    }
}

extension View {
    func tkStyle(_ style: TKTextStyle) -> some View {
        modifier(TKTextStyleModifier(style: style))
    }
}

extension Text {
    /// Uppercases the text for `overline` / `badge` tokens.
    func tkStyled(_ style: TKTextStyle) -> some View {
        textCase(style.uppercase ? .uppercase : nil).tkStyle(style)
    }
}
