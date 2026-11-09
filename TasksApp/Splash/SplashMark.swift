import SwiftUI
import Shared

/// Splash art: the app icon drawn in its 1024 space and mapped through the shared viewBox.
/// Everything numeric about *time* comes from `SplashFrame`; this file only holds the static icon artwork that
/// `MotionSpec` documents in comments (card/disc/check geometry, colours), as named private constants.
enum SplashArt {
    // Colours
    static let background = Color("SplashBackground") // #0A0A0A, same colour set as the launch screen
    static let wordmark = Color(red: 1, green: 1, blue: 1) // #FFFFFF
    static let caption = Color(red: 0xB3 / 255, green: 0xB3 / 255, blue: 0xAD / 255) // #B3B3AD

    fileprivate static let cardColor = Color(red: 1, green: 1, blue: 1) // #FFFFFF
    fileprivate static let discColor = Color(red: 0xE3 / 255, green: 0xF1 / 255, blue: 0x40 / 255) // #E3F140
    fileprivate static let checkColor = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255) // #0A0A0A

    // Icon art in 1024 space (MotionSpec.Splash comment)
    fileprivate static let cardRect = CGRect(x: 196, y: 334, width: 440, height: 440)
    fileprivate static let cardCorner: CGFloat = 124
    fileprivate static let cardStroke: CGFloat = 40
    fileprivate static let discRadius: CGFloat = 250
    fileprivate static let checkPoints = [CGPoint(x: 486, y: 438), CGPoint(x: 574, y: 526), CGPoint(x: 736, y: 346)]
    fileprivate static let checkStroke: CGFloat = 66
    /// The disc overshoots the mark box slightly (spring); the canvas is padded so nothing is clipped (SVG `overflow: visible`).
    fileprivate static let bleed: CGFloat = 24
}

/// The 132 x 120 mark. Draw order: card, disc, check. A stroke is not drawn at all while its trim is 0, so round caps
/// leave no dots.
struct SplashMark: View {
    let frame: SplashFrame

    private let spec = MotionSpec.Splash.shared

    var body: some View {
        let width = CGFloat(spec.MARK_WIDTH)
        let height = CGFloat(spec.MARK_HEIGHT)
        let bleed = SplashArt.bleed
        Canvas { context, _ in
            context.translateBy(x: bleed, y: bleed)
            context.scaleBy(x: width / CGFloat(spec.VIEWBOX_W), y: height / CGFloat(spec.VIEWBOX_H))
            context.translateBy(x: -CGFloat(spec.VIEWBOX_X), y: -CGFloat(spec.VIEWBOX_Y))
            draw(in: &context)
        }
        .frame(width: width + 2 * bleed, height: height + 2 * bleed)
        .frame(width: width, height: height)
    }

    private func draw(in context: inout GraphicsContext) {
        let cardTrim = CGFloat(frame.cardTrim)
        if cardTrim > 0 {
            context.stroke(
                Self.cardPath.trimmedPath(from: 0, to: min(cardTrim, 1)),
                with: .color(SplashArt.cardColor),
                style: StrokeStyle(lineWidth: SplashArt.cardStroke, lineCap: .butt, lineJoin: .miter)
            )
        }

        let discScale = max(0, CGFloat(frame.discScale))
        if discScale > 0 {
            let centre = CGPoint(x: CGFloat(spec.DISC_CX), y: CGFloat(spec.DISC_CY))
            let radius = SplashArt.discRadius * discScale
            let disc = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius))
            context.fill(disc, with: .color(SplashArt.discColor))
        }

        let checkTrim = CGFloat(frame.checkTrim)
        if checkTrim > 0 {
            context.stroke(
                Self.checkPath.trimmedPath(from: 0, to: min(checkTrim, 1)),
                with: .color(SplashArt.checkColor),
                style: StrokeStyle(lineWidth: SplashArt.checkStroke, lineCap: .round, lineJoin: .round)
            )
        }
    }

    /// Rounded rect traced like an SVG `<rect>`: starts after the top-left corner and runs clockwise.
    private static let cardPath: Path = {
        let rect = SplashArt.cardRect
        let r = SplashArt.cardCorner
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }()

    private static let checkPath: Path = {
        var path = Path()
        path.addLines(SplashArt.checkPoints)
        return path
    }()
}
