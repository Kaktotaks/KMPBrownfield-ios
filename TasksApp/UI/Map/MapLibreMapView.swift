import CoreLocation
import MapLibre
import Network
import Shared
import SwiftUI
import UIKit

/// Gestures and facts the map reports back. A reference type so the coordinator always calls the latest closures.
@MainActor
final class MapActions {
    var onSelect: (Int32) -> Void = { _ in }
    var onLongPress: (MapCoord) -> Void = { _ in }
    /// VoiceOver custom action "Add task here": the centre of the visible map.
    var onAddHere: (MapCoord) -> Void = { _ in }
    var onBackgroundTap: () -> Void = {}
    /// Move mode: the map centre under the fixed pin changed.
    var onMoveCenter: (MapCoord) -> Void = { _ in }
    var onOffline: (Bool) -> Void = { _ in }
}

/// `MLNMapView` for SwiftUI (handoff §3.1). The map is one clipped view with its own stacking context: tiles, route,
/// start marker, pins, dropped pin and move ghost are all inside it, so SwiftUI siblings (selector, chips, route sheet,
/// tab bar, sheets) always draw above (§3.4).
struct MapLibreMapView: UIViewRepresentable {
    let state: MapRenderState
    let camera: MapCameraRequest?
    let reloadToken: Int
    let actions: MapActions
    let accessibilityMapLabel: String
    let addHereLabel: String

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> MapCoordinator { MapCoordinator() }

    func makeUIView(context: Context) -> MapContainerView {
        let container = MapContainerView()
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ container: MapContainerView, context: Context) {
        context.coordinator.update(
            state: state,
            camera: camera,
            dark: colorScheme == .dark,
            reloadToken: reloadToken,
            actions: actions,
            mapLabel: accessibilityMapLabel,
            addHereLabel: addHereLabel
        )
    }

    static func dismantleUIView(_ container: MapContainerView, coordinator: MapCoordinator) {
        coordinator.detach()
    }
}

/// Root view of the map: the `MLNMapView`, the fixed centre pin of move mode, and the VoiceOver order.
final class MapContainerView: UIView {
    let mapView = MLNMapView(frame: .zero)
    private var centerPinHost: UIHostingController<AnyView>?
    var onLayout: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        mapView.frame = bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(mapView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }

    /// The lifted pin fixed above the map while the map pans under it (move mode).
    func setCenterPin(_ model: MapPinModel?, at point: CGPoint) {
        guard let model else {
            centerPinHost?.view.isHidden = true
            return
        }
        let content = AnyView(TaskPinView(model: model))
        if let host = centerPinHost {
            host.rootView = content
        } else {
            let host = UIHostingController(rootView: content)
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.safeAreaRegions = []
            host.view.bounds = CGRect(origin: .zero, size: PinAnnotationView.size)
            addSubview(host.view)
            centerPinHost = host
        }
        guard let view = centerPinHost?.view else { return }
        view.isHidden = false
        // The pin anchor (28, 46) sits on `point`.
        view.frame = CGRect(x: point.x - 28, y: point.y - 46, width: PinAnnotationView.size.width, height: PinAnnotationView.size.height)
        view.layer.zPosition = 10
    }
}

@MainActor
final class MapCoordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
    private weak var container: MapContainerView?
    private var mapView: MLNMapView { container!.mapView }

    private var state = MapRenderState()
    private var actions = MapActions()
    private var dark: Bool?
    private var styleLoaded = false
    private var reloadToken = 0
    private var lastCameraId: Int?
    private var pendingCamera: MapCameraRequest?
    private var layout = MapLayout()
    private var didSetInitialCamera = false
    private var didApplyState = false
    private var transitioning = false
    private var queuedState: MapRenderState?

    private let routeRenderer = RouteRenderer()
    private var annotations: [MapPointAnnotation.Kind: MapPointAnnotation] = [:]
    private var pinModels: [Int32: MapPinModel] = [:]
    private var startAnnotationLabel = ""
    private var draftLabel = ""
    private var moveOriginal: MapCoord?
    private var movePinModel: MapPinModel?
    private var lastReportedCenter: MapCoord?
    private var lastCenterReport: CFTimeInterval = 0

    private var loadFailed = false
    private var pathSatisfied = true
    private let monitor = NWPathMonitor()
    private var mapElement: UIAccessibilityElement?
    private var mapLabel = ""
    private var addHereLabel = ""

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private var isMoving: Bool { state.move != nil }

    // MARK: - Setup

    func attach(to container: MapContainerView) {
        self.container = container
        let map = container.mapView
        map.delegate = self
        map.allowsRotating = false
        map.allowsTilting = false
        map.showsUserLocation = false
        map.automaticallyAdjustsContentInset = false
        map.minimumZoomLevel = 9
        map.maximumZoomLevel = 19
        map.compassView.isHidden = true
        map.logoView.isHidden = true
        // The attribution button stays visible (OpenStreetMap / OpenFreeMap); it is moved above the route sheet.
        map.attributionButtonPosition = .bottomLeft
        map.isAccessibilityElement = false

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delegate = self
        map.addGestureRecognizer(longPress)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        for case let recognizer as UITapGestureRecognizer in map.gestureRecognizers ?? [] where recognizer !== tap {
            tap.require(toFail: recognizer)
        }
        map.addGestureRecognizer(tap)

        container.onLayout = { [weak self] in self?.containerDidLayout() }

        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in self?.pathChanged(satisfied: satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "map.path"))
    }

    func detach() {
        monitor.cancel()
    }

    // MARK: - Update from SwiftUI

    func update(state newState: MapRenderState, camera: MapCameraRequest?, dark: Bool, reloadToken: Int,
                actions: MapActions, mapLabel: String, addHereLabel: String) {
        self.actions = actions
        self.mapLabel = mapLabel
        self.addHereLabel = addHereLabel
        layout = newState.layout
        updateAttributionMargins()

        if self.dark != dark {
            self.dark = dark
            styleLoaded = false
            mapView.styleURL = MapStyleStore.url(dark: dark)
        }
        if self.reloadToken != reloadToken {
            self.reloadToken = reloadToken
            reloadStyle()
        }

        if !didSetInitialCamera {
            didSetInitialCamera = true
            mapView.setCenter(newState.start.clCoordinate, zoomLevel: 14, animated: false)
        }

        if newState.dayKey != state.dayKey, didApplyState, !transitioning {
            changeDay(to: newState)
        } else if transitioning {
            queuedState = newState
        } else {
            apply(newState, animateRoute: !didApplyState)
        }
        didApplyState = true

        if let camera, camera.id != lastCameraId {
            lastCameraId = camera.id
            if transitioning || mapView.bounds.isEmpty || !styleLoaded {
                pendingCamera = camera
            } else {
                perform(camera)
            }
        }
    }

    /// Day change: pins fade / scale out and in (200 ms; 150 ms cross-fade with Reduce Motion), the route redraws.
    private func changeDay(to newState: MapRenderState) {
        transitioning = true
        let half: TimeInterval = reduceMotion ? 0.075 : 0.1
        let views = annotationViews()
        UIView.animate(withDuration: half, delay: 0, options: [.curveEaseIn]) {
            for view in views {
                view.alpha = 0
                if !self.reduceMotion { view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9) }
            }
        } completion: { _ in
            self.transitioning = false
            let target = self.queuedState ?? newState
            self.queuedState = nil
            self.apply(target, animateRoute: true)
            let fresh = self.annotationViews()
            for view in fresh { view.alpha = 0; view.transform = self.reduceMotion ? .identity : CGAffineTransform(scaleX: 0.9, y: 0.9) }
            UIView.animate(withDuration: half, delay: 0, options: [.curveEaseOut]) {
                for view in fresh { view.alpha = 1; view.transform = .identity }
            }
            if let pending = self.pendingCamera {
                self.pendingCamera = nil
                self.perform(pending)
            }
        }
    }

    private func annotationViews() -> [UIView] {
        annotations.values.compactMap { mapView.view(for: $0) }
    }

    // MARK: - Applying state

    private func apply(_ new: MapRenderState, animateRoute: Bool) {
        let old = state
        state = new

        syncAnnotations(old: old, new: new)

        if let palette = new.palette {
            routeRenderer.update(palette: palette, dim: new.move != nil ? 0.35 : 1)
        }
        if routeRenderer.isInstalled, old.route != new.route || old.dayKey != new.dayKey || animateRoute {
            let hadRoute = old.route.kind == .ready || old.route.kind == .fallback
            let animate = !reduceMotion && (new.route.kind == .ready || new.route.kind == .fallback)
                && (!hadRoute || old.dayKey != new.dayKey || animateRoute)
            routeRenderer.show(new.route, animated: animate)
        }

        updateMoveMode(old: old, new: new)
        updateOfflineGrid()
        updateTimeLabels()
        updateAccessibilityOrder()
    }

    private func syncAnnotations(old: MapRenderState, new: MapRenderState) {
        var wanted: Set<MapPointAnnotation.Kind> = [.start]

        // Start marker.
        startAnnotationLabel = new.startAccessibilityLabel
        upsert(.start, at: new.start)
        (viewForKind(.start) as? StartAnnotationView)?.apply(label: new.startAccessibilityLabel)

        // Pins.
        var models: [Int32: MapPinModel] = [:]
        for pin in new.pins {
            wanted.insert(.pin(pin.id))
            var model = pin
            model.showsTime = pinModels[pin.id]?.showsTime ?? true
            models[pin.id] = model
            upsert(.pin(pin.id), at: pin.coord)
        }
        pinModels = models
        for pin in new.pins { refreshPinView(pin.id) }

        // Dropped pin.
        if let draft = new.draft {
            wanted.insert(.draft)
            draftLabel = draft.accessibilityLabel
            upsert(.draft, at: draft.coord)
            (viewForKind(.draft) as? DraftAnnotationView)?.apply(label: draft.accessibilityLabel)
        }

        // Move ghost.
        if let move = new.move {
            wanted.insert(.ghost)
            upsert(.ghost, at: move.original)
        }

        let stale = annotations.keys.filter { !wanted.contains($0) }
        if !stale.isEmpty {
            mapView.removeAnnotations(stale.compactMap { annotations[$0] })
            for kind in stale { annotations[kind] = nil }
        }
    }

    private func upsert(_ kind: MapPointAnnotation.Kind, at coord: MapCoord) {
        if let existing = annotations[kind] {
            if MapCoord(existing.coordinate) != coord { existing.coordinate = coord.clCoordinate }
        } else {
            let annotation = MapPointAnnotation(kind: kind, coord: coord)
            annotations[kind] = annotation
            mapView.addAnnotation(annotation)
        }
    }

    private func viewForKind(_ kind: MapPointAnnotation.Kind) -> MLNAnnotationView? {
        guard let annotation = annotations[kind] else { return nil }
        return mapView.view(for: annotation)
    }

    private func refreshPinView(_ id: Int32) {
        guard let model = pinModels[id], let view = viewForKind(.pin(id)) as? PinAnnotationView else { return }
        if view.model != model { view.apply(model) }
        view.onActivate = { [weak self] in self?.actions.onSelect(id) }
    }

    // MARK: - Move mode

    /// Where the fixed pin sits: the centre of the band between the banner and the "new place" card.
    private var moveTarget: CGPoint {
        let height = mapView.bounds.height
        return CGPoint(x: mapView.bounds.midX, y: (layout.moveTop + (height - layout.moveBottom)) / 2)
    }

    private func updateMoveMode(old: MapRenderState, new: MapRenderState) {
        movePinModel = new.move?.pin
        moveOriginal = new.move?.original
        container?.setCenterPin(new.move?.pin, at: moveTarget)
        if new.move == nil {
            routeRenderer.setMoveLink(from: nil, to: nil)
            lastReportedCenter = nil
        } else {
            updateMoveLink()
        }
    }

    private func updateMoveLink() {
        guard let original = moveOriginal else { return }
        routeRenderer.setMoveLink(from: original.clCoordinate, to: mapView.convert(moveTarget, toCoordinateFrom: mapView))
    }

    private func reportMoveCenter(force: Bool) {
        guard isMoving, !mapView.bounds.isEmpty else { return }
        let center = MapCoord(mapView.convert(moveTarget, toCoordinateFrom: mapView))
        let now = CACurrentMediaTime()
        guard center != lastReportedCenter, force || now - lastCenterReport > 0.15 else { return }
        lastReportedCenter = center
        lastCenterReport = now
        actions.onMoveCenter(center)
    }

    // MARK: - Camera

    private func containerDidLayout() {
        updateAttributionMargins()
        if isMoving { container?.setCenterPin(movePinModel, at: moveTarget) }
        updateMapElementFrame()
        if let pending = pendingCamera, !mapView.bounds.isEmpty, !transitioning, styleLoaded {
            pendingCamera = nil
            perform(pending)
        }
    }

    private func updateAttributionMargins() {
        // Above the collapsed route sheet; OSM / OpenFreeMap credit stays visible.
        mapView.attributionButtonMargins = CGPoint(x: 8, y: max(8, layout.fitBottom - 24))
    }

    private func perform(_ request: MapCameraRequest) {
        let animated = !reduceMotion
        let size = mapView.bounds.size
        switch request.kind {
        case .fit:
            fitRoute(animated: animated)
        case .centerStart(let start):
            // Fixed zoom 14; the visible band is between the selector and the route sheet.
            let target = CGPoint(x: size.width / 2, y: (layout.top + (size.height - layout.fitBottom)) / 2)
            move(start, to: target, zoom: 14, animated: animated)
        case .focusPin(let coord):
            let band = (top: layout.top, bottom: size.height - layout.taskSheetBottom)
            move(coord, to: CGPoint(x: size.width / 2, y: max(band.top, (band.top + band.bottom) / 2)), zoom: nil, animated: animated)
        case .focusDraft(let coord):
            let sheetTop = size.height - layout.draftSheetBottom
            move(coord, to: CGPoint(x: size.width / 2, y: max(70, sheetTop - 32)), zoom: nil, animated: animated)
        case .focusMove(let coord):
            move(coord, to: moveTarget, zoom: nil, animated: animated)
        }
    }

    /// Camera fits start + stops (or the whole route geometry) inside the free band: top = selector bottom + 24,
    /// bottom = route sheet + 24, sides 48.
    private func fitRoute(animated: Bool) {
        var coords: [CLLocationCoordinate2D] = [state.start.clCoordinate]
        coords += state.pins.map(\.coord.clCoordinate)
        for leg in state.route.legs { coords += leg.coords.map(\.clCoordinate) }
        if let moving = state.move { coords.append(moving.original.clCoordinate) }
        guard coords.count > 1 else {
            move(state.start, to: CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY), zoom: 14, animated: animated)
            return
        }
        let padding = UIEdgeInsets(top: layout.top, left: 48, bottom: layout.fitBottom, right: 48)
        var copy = coords
        mapView.setVisibleCoordinates(&copy, count: UInt(copy.count), edgePadding: padding, direction: -1,
                                      duration: animated ? 0.4 : 0,
                                      animationTimingFunction: CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1),
                                      completionHandler: nil)
    }

    /// Pans (and optionally zooms) so `coord` ends up at `target` in map-view points.
    private func move(_ coord: MapCoord, to target: CGPoint, zoom: Double?, animated: Bool) {
        let size = mapView.bounds.size
        guard !size.equalTo(.zero) else { return }
        let duration: TimeInterval = animated ? 0.3 : 0
        let timing = CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1)
        // A zoom change is applied first (about the coordinate) so the shift below is computed at the final zoom.
        if let zoom { mapView.setCenter(coord.clCoordinate, zoomLevel: zoom, animated: false) }
        let current = mapView.convert(coord.clCoordinate, toPointTo: mapView)
        let dx = target.x - current.x
        let dy = target.y - current.y
        let newCenterPoint = CGPoint(x: size.width / 2 - dx, y: size.height / 2 - dy)
        let newCenter = mapView.convert(newCenterPoint, toCoordinateFrom: mapView)
        let camera = MLNMapCamera(lookingAtCenter: newCenter, altitude: mapView.camera.altitude, pitch: 0, heading: 0)
        mapView.setCamera(camera, withDuration: duration, animationTimingFunction: timing, completionHandler: nil)
    }

    // MARK: - Style, offline

    private func reloadStyle() {
        guard let dark else { return }
        loadFailed = false
        styleLoaded = false
        mapView.styleURL = MapStyleStore.url(dark: dark)
    }

    private func pathChanged(satisfied: Bool) {
        let wasSatisfied = pathSatisfied
        pathSatisfied = satisfied
        if !satisfied {
            actions.onOffline(true)
        } else if !wasSatisfied || loadFailed {
            reloadStyle()
        }
    }

    private func updateOfflineGrid() {
        guard styleLoaded, let style = mapView.style, let dark else { return }
        let id = "offline-grid"
        let existing = style.layer(withIdentifier: id)
        if state.tilesOffline {
            guard existing == nil else { return }
            let palette = MapStyle.shared.palette(dark: dark)
            style.setImage(Self.gridImage(color: UIColor(hex: palette.roadCasing)), forName: id)
            let layer = MLNBackgroundStyleLayer(identifier: id)
            layer.backgroundPattern = NSExpression(forConstantValue: id)
            if let background = style.layer(withIdentifier: MapStyle.shared.LAYER_IDS.first ?? "background") {
                style.insertLayer(layer, above: background)
            } else {
                style.insertLayer(layer, at: 0)
            }
        } else if let existing {
            style.removeLayer(existing)
        }
    }

    /// 64 pt tile with a 1 pt line on its left and top edge: the "no tiles" grid of the design.
    private static func gridImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 1))
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 64))
        }
    }

    // MARK: - Collisions (time labels)

    /// If two pin anchors are closer than 24 pt, the lower pin hides its time label. Order badges always stay.
    private func updateTimeLabels() {
        guard !mapView.bounds.isEmpty else { return }
        let anchored = pinModels.values.map { ($0.id, mapView.convert($0.coord.clCoordinate, toPointTo: mapView)) }
        var hidden: Set<Int32> = []
        for (idA, a) in anchored {
            for (idB, b) in anchored where idA != idB {
                guard hypot(a.x - b.x, a.y - b.y) < 24 else { continue }
                // The lower one (larger y; ties by id) drops its label.
                if a.y > b.y || (a.y == b.y && idA > idB) { hidden.insert(idA) }
            }
        }
        for (id, model) in pinModels {
            let shows = !hidden.contains(id)
            guard model.showsTime != shows else { continue }
            var updated = model
            updated.showsTime = shows
            pinModels[id] = updated
            refreshPinView(id)
        }
    }

    // MARK: - Accessibility

    /// VoiceOver order: the map (with "Add task here"), the start marker, the pins in route order, the dropped pin.
    private func updateAccessibilityOrder() {
        guard let container else { return }
        let element = mapElement ?? UIAccessibilityElement(accessibilityContainer: container)
        mapElement = element
        element.accessibilityLabel = mapLabel
        element.accessibilityTraits = []
        let addHere = UIAccessibilityCustomAction(name: addHereLabel) { [weak self] _ in
            guard let self else { return false }
            self.actions.onAddHere(MapCoord(self.mapView.centerCoordinate))
            return true
        }
        element.accessibilityCustomActions = [addHere]
        updateMapElementFrame()

        var elements: [Any] = [element]
        if let start = viewForKind(.start) { elements.append(start) }
        let ordered = pinModels.values.sorted { lhs, rhs in
            switch (lhs.order, rhs.order) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.id < rhs.id
            }
        }
        for model in ordered {
            if let view = viewForKind(.pin(model.id)) { elements.append(view) }
        }
        if let draft = viewForKind(.draft) { elements.append(draft) }
        container.accessibilityElements = elements
    }

    private func updateMapElementFrame() {
        guard let container, let mapElement else { return }
        mapElement.accessibilityFrameInContainerSpace = container.bounds
    }

    // MARK: - Gestures

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, !isMoving else { return }
        let point = recognizer.location(in: mapView)
        // A long press on a pin is not "add here".
        if hitAnnotation(at: point) != nil { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        actions.onLongPress(MapCoord(mapView.convert(point, toCoordinateFrom: mapView)))
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, !isMoving else { return }
        if hitAnnotation(at: recognizer.location(in: mapView)) != nil { return }
        actions.onBackgroundTap()
    }

    private func hitAnnotation(at point: CGPoint) -> MLNAnnotationView? {
        var view: UIView? = mapView.hitTest(point, with: nil)
        while let current = view, current !== mapView {
            if let annotationView = current as? MLNAnnotationView { return annotationView }
            view = current.superview
        }
        return nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: - MLNMapViewDelegate

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        styleLoaded = true
        routeRenderer.install(in: style)
        if let palette = state.palette { routeRenderer.update(palette: palette, dim: isMoving ? 0.35 : 1) }
        routeRenderer.show(state.route, animated: false)
        updateOfflineGrid()
        updateMoveLink()
        if let pending = pendingCamera, !mapView.bounds.isEmpty, !transitioning {
            pendingCamera = nil
            perform(pending)
        }
    }

    func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
        loadFailed = true
        actions.onOffline(true)
    }

    func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
        loadFailed = false
        if pathSatisfied { actions.onOffline(false) }
    }

    func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard let annotation = annotation as? MapPointAnnotation else { return nil }
        switch annotation.kind {
        case .pin(let id):
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "pin") as? PinAnnotationView)
                ?? PinAnnotationView(reuseIdentifier: "pin")
            if let model = pinModels[id] { view.apply(model) }
            view.onActivate = { [weak self] in self?.actions.onSelect(id) }
            return view
        case .start:
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "start") as? StartAnnotationView)
                ?? StartAnnotationView(reuseIdentifier: "start")
            view.apply(label: startAnnotationLabel)
            return view
        case .draft:
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "draft") as? DraftAnnotationView)
                ?? DraftAnnotationView(reuseIdentifier: "draft")
            view.apply(label: draftLabel)
            return view
        case .ghost:
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "ghost") as? GhostAnnotationView)
                ?? GhostAnnotationView(reuseIdentifier: "ghost")
            view.apply()
            return view
        }
    }

    func mapView(_ mapView: MLNMapView, didAdd annotationViews: [MLNAnnotationView]) {
        updateTimeLabels()
        updateAccessibilityOrder()
    }

    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool { false }

    func mapView(_ mapView: MLNMapView, didSelect annotationView: MLNAnnotationView) {
        guard let annotation = annotationView.annotation as? MapPointAnnotation else { return }
        mapView.deselectAnnotation(annotation, animated: false)
        if case .pin(let id) = annotation.kind, !isMoving {
            actions.onSelect(id)
        }
    }

    func mapViewRegionIsChanging(_ mapView: MLNMapView) {
        updateTimeLabels()
        if isMoving {
            updateMoveLink()
            reportMoveCenter(force: false)
        }
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        updateTimeLabels()
        if isMoving {
            updateMoveLink()
            reportMoveCenter(force: true)
        }
    }
}
