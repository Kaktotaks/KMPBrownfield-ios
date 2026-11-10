import CoreLocation
import MapLibre
import QuartzCore
import Shared
import UIKit

/// Draws the route as GeoJSON line layers added at runtime above the roads and below the labels (handoff §3.2).
/// Layers: past legs (rim casing + grey line at 45 %), live legs (casing + lime line), pending (dashed straight
/// segments while the route is built) and the move link. The "draw from Start" animation trims the geometry per frame
/// (600 ms, `MotionSpec.emphasized`).
@MainActor
final class RouteRenderer: NSObject {
    private var style: MLNStyle?
    private var pastSource = MLNShapeSource(identifier: "route-past", shape: nil, options: nil)
    private var liveSource = MLNShapeSource(identifier: "route-live", shape: nil, options: nil)
    private var pendingSource = MLNShapeSource(identifier: "route-pending", shape: nil, options: nil)
    private var linkSource = MLNShapeSource(identifier: "route-move-link", shape: nil, options: nil)
    private var pastCasing: MLNLineStyleLayer?
    private var pastLine: MLNLineStyleLayer?
    private var liveCasing: MLNLineStyleLayer?
    private var liveLine: MLNLineStyleLayer?
    private var pendingLine: MLNLineStyleLayer?
    private var linkLine: MLNLineStyleLayer?

    private var route = MapRouteModel.none
    private var palette: MapRoutePalette?
    private var dim: CGFloat = 1
    private var displayLink: CADisplayLink?
    private var animationStart: CFTimeInterval = 0
    private static let drawDuration: CFTimeInterval = 0.6

    var isInstalled: Bool { style != nil }

    /// Adds sources and layers to a freshly loaded style (call again after every style change).
    func install(in style: MLNStyle) {
        cancelAnimation()
        self.style = style
        // An MLNSource can belong to one style only: after a style reload the old instances throw in addSource.
        pastSource = MLNShapeSource(identifier: "route-past", shape: nil, options: nil)
        liveSource = MLNShapeSource(identifier: "route-live", shape: nil, options: nil)
        pendingSource = MLNShapeSource(identifier: "route-pending", shape: nil, options: nil)
        linkSource = MLNShapeSource(identifier: "route-move-link", shape: nil, options: nil)
        for id in ["route-move-link-line", "route-pending-line", "route-live-line", "route-live-casing", "route-past-line", "route-past-casing"] {
            if let layer = style.layer(withIdentifier: id) { style.removeLayer(layer) }
        }
        for source in [pastSource, liveSource, pendingSource, linkSource] {
            if let old = style.source(withIdentifier: source.identifier) { style.removeSource(old) }
            style.addSource(source)
        }
        let below = style.layer(withIdentifier: MapStyle.shared.ROUTE_BELOW_LAYER)
        func make(_ id: String, _ source: MLNShapeSource) -> MLNLineStyleLayer {
            let layer = MLNLineStyleLayer(identifier: id, source: source)
            layer.lineJoin = NSExpression(forConstantValue: "round")
            if let below { style.insertLayer(layer, below: below) } else { style.addLayer(layer) }
            return layer
        }
        pastCasing = make("route-past-casing", pastSource)
        pastLine = make("route-past-line", pastSource)
        liveCasing = make("route-live-casing", liveSource)
        liveLine = make("route-live-line", liveSource)
        pendingLine = make("route-pending-line", pendingSource)
        linkLine = make("route-move-link-line", linkSource)
        configureLayers()
        setShapes(progress: 1)
    }

    // MARK: - Styling

    func update(palette: MapRoutePalette, dim: CGFloat) {
        guard self.palette != palette || self.dim != dim else { return }
        self.palette = palette
        self.dim = dim
        configureLayers()
    }

    private func constant(_ value: Any) -> NSExpression { NSExpression(forConstantValue: value) }

    /// Dash arrays are in multiples of the line width in MapLibre; the palette has them in points.
    private func dash(_ points: [CGFloat], width: CGFloat) -> NSExpression? {
        guard !points.isEmpty, width > 0 else { return nil }
        return constant(points.map { NSNumber(value: Double($0 / width)) })
    }

    private func configureLayers() {
        guard let palette else { return }
        let dashed = route.kind == .fallback
        let cap = constant(dashed ? "butt" : "round")
        let rim = max(0.5, (palette.casingWidth - palette.lineWidth) / 2)

        liveCasing?.lineColor = constant(palette.casing)
        liveCasing?.lineWidth = constant(palette.casingWidth)
        liveCasing?.lineGapWidth = constant(0)
        liveCasing?.lineOpacity = constant(dim)
        liveCasing?.lineCap = cap
        liveCasing?.lineDashPattern = dashed ? dash(palette.fallbackDash, width: palette.casingWidth) : nil

        liveLine?.lineColor = constant(palette.line)
        liveLine?.lineWidth = constant(palette.lineWidth)
        liveLine?.lineOpacity = constant(dim)
        liveLine?.lineCap = cap
        liveLine?.lineDashPattern = dashed ? dash(palette.fallbackDash, width: palette.lineWidth) : nil

        // Past legs: casing + grey line at 45 % *as a group*. The casing is drawn as a rim only (gap = line width), so
        // translucent layers don't show the casing through the line.
        pastCasing?.lineColor = constant(palette.casing)
        pastCasing?.lineWidth = constant(rim)
        pastCasing?.lineGapWidth = constant(palette.lineWidth)
        pastCasing?.lineOpacity = constant(palette.pastOpacity * dim)
        pastCasing?.lineCap = cap
        pastCasing?.lineDashPattern = dashed ? dash(palette.fallbackDash, width: rim) : nil

        pastLine?.lineColor = constant(palette.pastLine)
        pastLine?.lineWidth = constant(palette.lineWidth)
        pastLine?.lineOpacity = constant(palette.pastOpacity * dim)
        pastLine?.lineCap = cap
        pastLine?.lineDashPattern = dashed ? dash(palette.fallbackDash, width: palette.lineWidth) : nil

        pendingLine?.lineColor = constant(palette.pending)
        pendingLine?.lineWidth = constant(palette.pendingWidth)
        pendingLine?.lineOpacity = constant(dim)
        pendingLine?.lineCap = constant("round")
        pendingLine?.lineDashPattern = dash(palette.pendingDash, width: palette.pendingWidth)

        linkLine?.lineColor = constant(palette.pending)
        linkLine?.lineWidth = constant(2)
        linkLine?.lineCap = constant("butt")
        linkLine?.lineDashPattern = dash([4, 4], width: 2)
    }

    // MARK: - Route

    /// Shows `route`. `animated` draws it from Start (600 ms); otherwise it appears at once.
    func show(_ route: MapRouteModel, animated: Bool) {
        let changedKind = route.kind != self.route.kind
        cancelAnimation()
        self.route = route
        if changedKind { configureLayers() }
        guard style != nil else { return }
        if animated, route.kind == .ready || route.kind == .fallback, !route.legs.isEmpty {
            animationStart = CACurrentMediaTime()
            setShapes(progress: 0)
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            setShapes(progress: 1)
        }
    }

    func setMoveLink(from: CLLocationCoordinate2D?, to: CLLocationCoordinate2D?) {
        guard let from, let to else { linkSource.shape = nil; return }
        var coords = [from, to]
        linkSource.shape = MLNPolylineFeature(coordinates: &coords, count: 2)
    }

    @objc private func tick() {
        let fraction = min(1, (CACurrentMediaTime() - animationStart) / Self.drawDuration)
        let eased = Double(MotionSpec.shared.emphasized.transform(fraction: Float(fraction)))
        setShapes(progress: eased)
        if fraction >= 1 { cancelAnimation() }
    }

    private func cancelAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func setShapes(progress: Double) {
        switch route.kind {
        case .none:
            pastSource.shape = nil
            liveSource.shape = nil
            pendingSource.shape = nil
        case .pending:
            pastSource.shape = nil
            liveSource.shape = nil
            pendingSource.shape = Self.polyline(route.pendingPoints.map(\.clCoordinate))
        case .ready, .fallback:
            pendingSource.shape = nil
            let parts = Self.trimmed(route.legs, progress: progress)
            pastSource.shape = Self.collection(parts.past)
            liveSource.shape = Self.collection(parts.live)
        }
    }

    // MARK: - Geometry helpers (pure; no routing logic: the geometry comes from shared)

    static func polyline(_ coords: [CLLocationCoordinate2D]) -> MLNShape? {
        guard coords.count >= 2 else { return nil }
        var copy = coords
        return MLNPolylineFeature(coordinates: &copy, count: UInt(copy.count))
    }

    private static func collection(_ lines: [[CLLocationCoordinate2D]]) -> MLNShape? {
        let shapes = lines.compactMap { polyline($0) as? MLNPolylineFeature }
        return shapes.isEmpty ? nil : MLNShapeCollectionFeature(shapes: shapes)
    }

    static func length(_ coords: [CLLocationCoordinate2D]) -> Double {
        zip(coords, coords.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// The first `progress` (0…1) of the whole route's length, split into past and live legs.
    static func trimmed(_ legs: [MapLegModel], progress: Double) -> (past: [[CLLocationCoordinate2D]], live: [[CLLocationCoordinate2D]]) {
        let lines = legs.map { $0.coords.map(\.clCoordinate) }
        let lengths = lines.map(length)
        var remaining = lengths.reduce(0, +) * min(max(progress, 0), 1)
        var past: [[CLLocationCoordinate2D]] = []
        var live: [[CLLocationCoordinate2D]] = []
        for (index, line) in lines.enumerated() {
            guard remaining > 0 else { break }
            let part: [CLLocationCoordinate2D]
            if remaining >= lengths[index] {
                part = line
                remaining -= lengths[index]
            } else {
                part = prefix(of: line, length: remaining)
                remaining = 0
            }
            if legs[index].isPast { past.append(part) } else { live.append(part) }
        }
        return (past, live)
    }

    static func prefix(of line: [CLLocationCoordinate2D], length target: Double) -> [CLLocationCoordinate2D] {
        guard let first = line.first else { return [] }
        var result = [first]
        var travelled = 0.0
        for (a, b) in zip(line, line.dropFirst()) {
            let segment = distance(a, b)
            if travelled + segment >= target {
                let t = segment == 0 ? 0 : (target - travelled) / segment
                result.append(CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                                     longitude: a.longitude + (b.longitude - a.longitude) * t))
                return result
            }
            travelled += segment
            result.append(b)
        }
        return result
    }
}
