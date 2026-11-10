import MapLibre
import SwiftUI
import UIKit

/// Annotation model: one per pin, plus the start marker, the dropped pin and the move ghost.
final class MapPointAnnotation: MLNPointAnnotation {
    enum Kind: Hashable {
        case pin(Int32)
        case start
        case draft
        case ghost
    }

    let kind: Kind

    init(kind: Kind, coord: MapCoord) {
        self.kind = kind
        super.init()
        coordinate = coord.clCoordinate
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

/// `MLNAnnotationView` that hosts a SwiftUI view (the design's `TaskPin`, `StartMarker`, …) so pins are real views:
/// they move with the map, are VoiceOver elements in route order, and live inside the map's own view hierarchy,
/// which is clipped and sits below every SwiftUI overlay (handoff §3.4).
class SwiftUIAnnotationView: MLNAnnotationView {
    private var host: UIHostingController<AnyView>?

    func setContent<Content: View>(_ content: Content, size: CGSize) {
        frame = CGRect(origin: .zero, size: size)
        let root = AnyView(content)
        if let host {
            host.rootView = root
        } else {
            let host = UIHostingController(rootView: root)
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.safeAreaRegions = []
            host.view.frame = bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(host.view)
            self.host = host
        }
        clipsToBounds = false
        backgroundColor = .clear
    }
}

final class PinAnnotationView: SwiftUIAnnotationView {
    static let size = CGSize(width: 56, height: 76)
    /// Called when VoiceOver activates the pin (a double tap); touch taps go through MapLibre's selection.
    var onActivate: (() -> Void)?
    private(set) var model: MapPinModel?

    func apply(_ model: MapPinModel) {
        self.model = model
        setContent(TaskPinView(model: model), size: Self.size)
        // The anchor (28, 46) sits on the coordinate: the view centre (28, 38) is 8 pt above it.
        centerOffset = CGVector(dx: 0, dy: -8)
        isAccessibilityElement = true
        accessibilityLabel = model.accessibilityLabel
        accessibilityTraits = model.isSelected ? [.button, .selected] : .button
        // Selected pins draw above the others.
        layer.zPosition = model.isSelected || model.isLifted ? 3 : 1
    }

    override func accessibilityActivate() -> Bool {
        onActivate?()
        return onActivate != nil
    }
}

final class StartAnnotationView: SwiftUIAnnotationView {
    static let size = CGSize(width: 240, height: 72)

    func apply(label: String) {
        setContent(StartMarkerView(), size: Self.size)
        // The marker centre is (120, 20) in the 240 x 72 view; the view centre is (120, 36).
        centerOffset = CGVector(dx: 0, dy: 16)
        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityTraits = .image
        layer.zPosition = 0
    }
}

final class DraftAnnotationView: SwiftUIAnnotationView {
    static let size = CGSize(width: 76, height: 76)

    func apply(label: String) {
        setContent(DroppedPinView(), size: Self.size)
        centerOffset = .zero
        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityTraits = .image
        layer.zPosition = 2
    }
}

final class GhostAnnotationView: SwiftUIAnnotationView {
    static let size = CGSize(width: 36, height: 36)

    func apply() {
        setContent(MoveGhostView(), size: Self.size)
        centerOffset = .zero
        isAccessibilityElement = false
        layer.zPosition = 0
    }
}
