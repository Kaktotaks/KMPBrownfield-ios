import SwiftUI

/// Minimal SVG path-data parser (M m L l H h V v C c S s Q q A a Z z) for the map icons, so the path strings of the
/// handoff markup (`design-handoff/map/components/*.dc.html`) are used verbatim (24 grid).
enum SVGPath {
    static func path(_ data: String) -> Path {
        var scanner = Scanner(data)
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?
        var command: Character = "M"

        while let next = scanner.nextCommand() {
            command = next
            let relative = command.isLowercase
            repeat {
                var cubic: CGPoint?
                var quad: CGPoint?
                switch command {
                case "M", "m":
                    guard let x = scanner.number(), let y = scanner.number() else { return path }
                    current = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                    start = current
                    path.move(to: current)
                    // Further coordinate pairs after a moveto are implicit linetos.
                    command = relative ? "l" : "L"
                case "L", "l":
                    guard let x = scanner.number(), let y = scanner.number() else { return path }
                    current = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                    path.addLine(to: current)
                case "H", "h":
                    guard let x = scanner.number() else { return path }
                    current.x = relative ? current.x + x : x
                    path.addLine(to: current)
                case "V", "v":
                    guard let y = scanner.number() else { return path }
                    current.y = relative ? current.y + y : y
                    path.addLine(to: current)
                case "C", "c":
                    guard let a = scanner.number(), let b = scanner.number(), let c = scanner.number(),
                          let d = scanner.number(), let e = scanner.number(), let f = scanner.number() else { return path }
                    let o = relative ? current : .zero
                    let c1 = CGPoint(x: o.x + a, y: o.y + b), c2 = CGPoint(x: o.x + c, y: o.y + d)
                    current = CGPoint(x: o.x + e, y: o.y + f)
                    path.addCurve(to: current, control1: c1, control2: c2)
                    cubic = c2
                case "S", "s":
                    guard let c = scanner.number(), let d = scanner.number(),
                          let e = scanner.number(), let f = scanner.number() else { return path }
                    let o = relative ? current : .zero
                    let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                    let c2 = CGPoint(x: o.x + c, y: o.y + d)
                    current = CGPoint(x: o.x + e, y: o.y + f)
                    path.addCurve(to: current, control1: c1, control2: c2)
                    cubic = c2
                case "Q", "q":
                    guard let a = scanner.number(), let b = scanner.number(),
                          let c = scanner.number(), let d = scanner.number() else { return path }
                    let o = relative ? current : .zero
                    let control = CGPoint(x: o.x + a, y: o.y + b)
                    current = CGPoint(x: o.x + c, y: o.y + d)
                    path.addQuadCurve(to: current, control: control)
                    quad = control
                case "A", "a":
                    guard let rx = scanner.number(), let ry = scanner.number(), let rot = scanner.number(),
                          let large = scanner.flag(), let sweep = scanner.flag(),
                          let x = scanner.number(), let y = scanner.number() else { return path }
                    let end = relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
                    addArc(&path, from: current, to: end, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                    current = end
                case "Z", "z":
                    path.closeSubpath()
                    current = start
                default:
                    return path
                }
                lastCubicControl = cubic
                lastQuadControl = quad
                if command == "Z" || command == "z" { break }
            } while scanner.hasNumber()
        }
        _ = lastQuadControl
        return path
    }

    // MARK: - Arc (SVG endpoint -> center parameterisation -> cubic segments)

    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint, rx rxIn: Double, ry ryIn: Double,
                               rotation: Double, large: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if p0 == p1 { return }
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s }
        let numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coefficient = denominator == 0 ? 0 : sqrt(max(0, numerator / denominator))
        if large == sweep { coefficient = -coefficient }
        let cxp = coefficient * rx * y1p / ry
        let cyp = -coefficient * ry * x1p / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / Double(segments)
        let t = 4.0 / 3.0 * tan(step / 4)
        var a = theta1
        for _ in 0..<segments {
            let b = a + step
            func point(_ angle: Double, _ dr: Double = 0) -> CGPoint {
                let x = rx * cos(angle), y = ry * sin(angle)
                return CGPoint(x: cosPhi * x - sinPhi * y + cx, y: sinPhi * x + cosPhi * y + cy)
            }
            func derivative(_ angle: Double) -> CGPoint {
                let x = -rx * sin(angle), y = ry * cos(angle)
                return CGPoint(x: cosPhi * x - sinPhi * y, y: sinPhi * x + cosPhi * y)
            }
            let pa = point(a), pb = point(b), da = derivative(a), db = derivative(b)
            path.addCurve(
                to: pb,
                control1: CGPoint(x: pa.x + t * da.x, y: pa.y + t * da.y),
                control2: CGPoint(x: pb.x - t * db.x, y: pb.y - t * db.y)
            )
            a = b
        }
    }

    // MARK: - Tokenizer

    private struct Scanner {
        private let chars: [Character]
        private var index = 0

        init(_ string: String) { chars = Array(string) }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" || chars[index] == "\t" {
                index += 1
            }
        }

        mutating func nextCommand() -> Character? {
            skipSeparators()
            guard index < chars.count else { return nil }
            let c = chars[index]
            if c.isLetter { index += 1; return c }
            return nil
        }

        mutating func hasNumber() -> Bool {
            skipSeparators()
            guard index < chars.count else { return false }
            let c = chars[index]
            return c.isNumber || c == "-" || c == "+" || c == "."
        }

        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < chars.count, chars[index] == "0" || chars[index] == "1" else { return nil }
            defer { index += 1 }
            return chars[index] == "1"
        }

        mutating func number() -> Double? {
            skipSeparators()
            let begin = index
            guard index < chars.count else { return nil }
            if chars[index] == "-" || chars[index] == "+" { index += 1 }
            var seenDot = false
            while index < chars.count {
                let c = chars[index]
                if c.isNumber { index += 1 } else if c == "." && !seenDot { seenDot = true; index += 1 } else { break }
            }
            return Double(String(chars[begin..<index]))
        }
    }
}
