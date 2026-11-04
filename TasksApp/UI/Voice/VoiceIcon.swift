import SwiftUI

/// Voice-note glyphs drawn on the same 24 grid as `TKIcon` (stroke 2.2, round caps). The generated `TKIconPaths`
/// are shared with Android, so these live here until the icon generator learns them.
enum VoiceIconName {
    case mic, micOff, play, pause, stop, externalLink
}

struct VoiceIcon: View {
    let name: VoiceIconName
    var size: CGFloat = 24

    var body: some View {
        Group {
            switch name {
            case .mic:
                VoiceGlyph(name: .mic).stroke(style: stroke)
            case .micOff:
                VoiceGlyph(name: .micOff).stroke(style: stroke)
            case .externalLink:
                VoiceGlyph(name: .externalLink).stroke(style: stroke)
            case .play, .pause, .stop:
                // Filled glyphs with a rounded join so the corners match the stroke icons.
                VoiceGlyph(name: name)
                    .fill()
                    .overlay(VoiceGlyph(name: name).stroke(style: StrokeStyle(lineWidth: 2 * size / 24, lineCap: .round, lineJoin: .round)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: 2.2 * size / 24, lineCap: .round, lineJoin: .round)
    }
}

private struct VoiceGlyph: Shape {
    let name: VoiceIconName

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        switch name {
        case .mic, .micOff:
            path.addRoundedRect(in: CGRect(x: 9 * s, y: 2.5 * s, width: 6 * s, height: 11 * s), cornerSize: CGSize(width: 3 * s, height: 3 * s))
            path.move(to: p(5.5, 11))
            path.addCurve(to: p(12, 17.5), control1: p(5.5, 14.6), control2: p(8.4, 17.5))
            path.addCurve(to: p(18.5, 11), control1: p(15.6, 17.5), control2: p(18.5, 14.6))
            path.move(to: p(12, 17.5))
            path.addLine(to: p(12, 21))
            if name == .micOff {
                path.move(to: p(4, 4))
                path.addLine(to: p(20, 20))
            }
        case .play:
            path.move(to: p(8, 5.5))
            path.addLine(to: p(18.5, 12))
            path.addLine(to: p(8, 18.5))
            path.closeSubpath()
        case .pause:
            path.addRoundedRect(in: CGRect(x: 7 * s, y: 5.5 * s, width: 3.5 * s, height: 13 * s), cornerSize: CGSize(width: 1 * s, height: 1 * s))
            path.addRoundedRect(in: CGRect(x: 13.5 * s, y: 5.5 * s, width: 3.5 * s, height: 13 * s), cornerSize: CGSize(width: 1 * s, height: 1 * s))
        case .stop:
            path.addRoundedRect(in: CGRect(x: 6.5 * s, y: 6.5 * s, width: 11 * s, height: 11 * s), cornerSize: CGSize(width: 2 * s, height: 2 * s))
        case .externalLink:
            path.move(to: p(10, 5))
            path.addLine(to: p(7, 5))
            path.addCurve(to: p(5, 7), control1: p(5.9, 5), control2: p(5, 5.9))
            path.addLine(to: p(5, 17))
            path.addCurve(to: p(7, 19), control1: p(5, 18.1), control2: p(5.9, 19))
            path.addLine(to: p(17, 19))
            path.addCurve(to: p(19, 17), control1: p(18.1, 19), control2: p(19, 18.1))
            path.addLine(to: p(19, 14))
            path.move(to: p(14, 4.5))
            path.addLine(to: p(19.5, 4.5))
            path.addLine(to: p(19.5, 10))
            path.move(to: p(19.5, 4.5))
            path.addLine(to: p(11, 13))
        }
        return path
    }
}
