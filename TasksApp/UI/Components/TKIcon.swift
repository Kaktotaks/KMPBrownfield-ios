import SwiftUI

/// Stroke icon on the 24 grid (stroke 2.2, round caps) drawn from the same path data as Android `TasksIcons`
/// (`Theme/TKIconPaths.swift`). Tint with `.foregroundStyle`.
struct TKIcon: View {
    let name: TKIconName
    var size: CGFloat = 24

    var body: some View {
        TKIconShape(name: name)
            .stroke(style: StrokeStyle(lineWidth: name.strokeWidth * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Minimal SVG path-data renderer: absolute `M`, `L`, `C`, `Z` only (what the icon generator emits).
struct TKIconShape: Shape {
    let name: TKIconName

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        for data in name.paths {
            path.addPath(Self.parse(data, scale: scale))
        }
        return path
    }

    private static func parse(_ data: String, scale: CGFloat) -> Path {
        var path = Path()
        let tokens = data
            .replacingOccurrences(of: "M", with: " M ")
            .replacingOccurrences(of: "L", with: " L ")
            .replacingOccurrences(of: "C", with: " C ")
            .replacingOccurrences(of: "Z", with: " Z ")
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map(String.init)
        var i = 0
        func point() -> CGPoint {
            defer { i += 2 }
            return CGPoint(x: (Double(tokens[i]) ?? 0) * scale, y: (Double(tokens[i + 1]) ?? 0) * scale)
        }
        var command = ""
        while i < tokens.count {
            if ["M", "L", "C", "Z"].contains(tokens[i]) {
                command = tokens[i]
                i += 1
                if command == "Z" { path.closeSubpath() }
                continue
            }
            switch command {
            case "M": path.move(to: point())
            case "L": path.addLine(to: point())
            case "C":
                let c1 = point(), c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
            default: i += 1
            }
        }
        return path
    }
}
