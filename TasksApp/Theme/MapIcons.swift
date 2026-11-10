import SwiftUI

/// Icons of the Map feature: the SVG path data of the handoff markup, drawn on the 24 grid (round caps/joins).
/// `filled` icons (flame, star) are solid shapes; the rest are strokes (`MapIconView.stroke`, default 2.2).
enum MapIcon {
    case pin, pinAdd, flame, star, leaf, check, home, car, locate, move, chevronLeft, chevronRight
    case clock, pencil, trash, close, alert, wifiOff

    var paths: [String] {
        switch self {
        case .pin: return [
            "M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z",
            "M9.6 10a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0 -4.8 0"]
        case .pinAdd: return [
            "M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z",
            "M12 7.5v5M9.5 10h5"]
        case .flame: return ["M12 2.5c1 3.6 5.5 5.6 5.5 10.6a5.5 5.5 0 0 1-11 0c0-2.4 1.3-4 2.6-5 .2 1.7 1.1 2.8 2.3 3.1-.6-3.1.1-6.1.6-8.7z"]
        case .star: return ["M12 3.2l2.7 5.5 6 .9-4.35 4.25 1.03 6-5.38-2.83-5.38 2.83 1.03-6L3.3 9.6l6-.9z"]
        case .leaf: return ["M5 19.5C5 11 10 5.5 19.5 4.5 19.5 14 14 19 5.5 19M5 19.5l8.5-8.5"]
        case .check: return ["M5 12.5l4.5 4.5L19 7.5"]
        case .home: return ["M4 11l8-6.5 8 6.5M6.5 9.5V19h11V9.5M10 19v-5h4v5"]
        case .car: return ["M5 16V11l2-5h10l2 5v5M5 16h14M5 16v2M19 16v2M5 11h14"]
        case .locate: return [
            "M5.5 12a6.5 6.5 0 1 0 13 0a6.5 6.5 0 1 0 -13 0",
            "M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3"]
        case .move: return ["M12 3v18M3 12h18M12 3l-2.5 2.5M12 3l2.5 2.5M12 21l-2.5-2.5M12 21l2.5-2.5M3 12l2.5-2.5M3 12l2.5 2.5M21 12l-2.5-2.5M21 12l-2.5 2.5"]
        case .chevronLeft: return ["M15 5l-7 7 7 7"]
        case .chevronRight: return ["M9 5l7 7-7 7"]
        case .clock: return ["M3.5 12a8.5 8.5 0 1 0 17 0a8.5 8.5 0 1 0 -17 0", "M12 7.5V12l3 2"]
        case .pencil: return ["M4 20h4L19 9l-4-4L4 16v4z"]
        case .trash: return ["M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"]
        case .close: return ["M6 6l12 12M18 6L6 18"]
        case .alert: return ["M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0", "M12 7.5v5.5M12 16.5v.01"]
        case .wifiOff: return ["M3 3l18 18M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 5-2.6M19 13a10 10 0 0 0-2.2-1.5M2 9.5a15 15 0 0 1 4.3-2.6M22 9.5A15 15 0 0 0 11 6M12 20h.01"]
        }
    }

    var isFilled: Bool { self == .flame || self == .star }
}

struct MapIconShape: Shape {
    let icon: MapIcon

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var result = Path()
        for data in icon.paths {
            result.addPath(SVGPath.path(data).applying(CGAffineTransform(scaleX: scale, y: scale)))
        }
        return result
    }
}

/// `foregroundStyle` tints it. `stroke` is in 24-grid units (scaled with `size`).
struct MapIconView: View {
    let icon: MapIcon
    var size: CGFloat = 20
    var stroke: CGFloat = 2.2

    var body: some View {
        Group {
            if icon.isFilled {
                MapIconShape(icon: icon).fill()
            } else {
                MapIconShape(icon: icon)
                    .stroke(style: StrokeStyle(lineWidth: stroke * size / 24, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
