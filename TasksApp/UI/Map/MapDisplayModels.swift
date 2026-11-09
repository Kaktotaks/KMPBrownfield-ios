import CoreLocation
import UIKit
import Shared

/// Display-ready values of the Map screen, mapped from the shared `MapUiState` by `MapViewModel`.
/// Plain `Equatable` structs: the MapLibre coordinator diffs them to update only what changed.

struct MapCoord: Equatable {
    var lat: Double
    var lng: Double

    init(lat: Double, lng: Double) { self.lat = lat; self.lng = lng }
    init(_ point: GeoPoint) { self.init(lat: point.lat, lng: point.lng) }
    init(_ coordinate: CLLocationCoordinate2D) { self.init(lat: coordinate.latitude, lng: coordinate.longitude) }

    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
    var geoPoint: GeoPoint { GeoPoint(lat: lat, lng: lng) }
}

/// One pin (`TaskPin`): everything the view needs, no Kotlin types.
struct MapPinModel: Equatable, Identifiable {
    let id: Int32
    let coord: MapCoord
    let order: Int?
    /// "13:15"; nil for pins without a time.
    let time: String?
    let title: String
    let priority: Priority
    let isDone: Bool
    let isOverdue: Bool
    let isPast: Bool
    var isSelected = false
    var isLifted = false
    /// False when another pin's anchor is closer than 24 pt (the lower one drops its time label).
    var showsTime = true
    let accessibilityLabel: String
}

/// One leg of the drawn route.
struct MapLegModel: Equatable {
    let coords: [MapCoord]
    /// Leg into a past stop: casing + grey line at 45 %.
    let isPast: Bool
}

struct MapRouteModel: Equatable {
    enum Kind: Equatable { case none, pending, ready, fallback }

    var kind: Kind = .none
    var legs: [MapLegModel] = []
    /// Loading: start + routed stops, joined by straight dashed segments.
    var pendingPoints: [MapCoord] = []

    static let none = MapRouteModel()
}

/// Route colours / widths / dashes from `MapStyle.routePalette(dark)` (shared), as UIKit values.
struct MapRoutePalette: Equatable {
    let casing: UIColor
    let casingWidth: CGFloat
    let line: UIColor
    let lineWidth: CGFloat
    let pending: UIColor
    let pendingWidth: CGFloat
    let pendingDash: [CGFloat]
    let fallbackDash: [CGFloat]
    let pastLine: UIColor
    let pastOpacity: CGFloat

    init(_ palette: RoutePalette) {
        casing = UIColor(hex: palette.casing)
        casingWidth = CGFloat(palette.casingWidth)
        line = UIColor(hex: palette.line)
        lineWidth = CGFloat(palette.lineWidth)
        pending = UIColor(hex: palette.pending)
        pendingWidth = CGFloat(palette.pendingWidth)
        pendingDash = palette.pendingDash.map { CGFloat($0.floatValue) }
        fallbackDash = palette.fallbackDash.map { CGFloat($0.floatValue) }
        pastLine = UIColor(hex: palette.pastLine)
        pastOpacity = CGFloat(palette.pastOpacity)
    }
}

struct MapMoveModel: Equatable {
    /// Where the pin was; the dashed ghost marks it.
    let original: MapCoord
    /// The pin being moved, drawn lifted at the fixed centre while the map pans under it.
    let pin: MapPinModel
}

struct MapDraftModel: Equatable {
    let coord: MapCoord
    let accessibilityLabel: String
}

/// Screen space the map may use, measured by the SwiftUI layout (points from the top / bottom of the map view).
struct MapLayout: Equatable {
    /// Bottom edge of the day selector + 24.
    var top: CGFloat = 130
    /// Fitting the route: the collapsed route sheet + tab bar + 24.
    var fitBottom: CGFloat = 283
    /// Centring a pin above the task sheet.
    var taskSheetBottom: CGFloat = 560
    /// Centring the dropped pin above the new-task sheet.
    var draftSheetBottom: CGFloat = 700
    /// Move mode: below the banner / above the "new place" card.
    var moveTop: CGFloat = 138
    var moveBottom: CGFloat = 220
}

/// One-shot camera command; `id` makes equal commands distinct.
struct MapCameraRequest: Equatable {
    enum Kind: Equatable {
        case fit
        case centerStart(MapCoord)
        case focusPin(MapCoord)
        case focusDraft(MapCoord)
        case focusMove(MapCoord)
    }

    let id: Int
    let kind: Kind
}

/// Everything the MapLibre view renders (value type; the coordinator applies the differences).
struct MapRenderState: Equatable {
    var dayKey = 0
    var start = MapCoord(lat: 0, lng: 0)
    var startAccessibilityLabel = ""
    var pins: [MapPinModel] = []
    var route = MapRouteModel.none
    var palette: MapRoutePalette?
    var move: MapMoveModel?
    var draft: MapDraftModel?
    var tilesOffline = false
    var layout = MapLayout()
}
