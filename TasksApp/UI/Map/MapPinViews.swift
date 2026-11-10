import SwiftUI
import Shared

/// Annulus (ring) between two radii, centred: what a CSS `box-shadow: 0 0 0 Npx` looks like around a circle.
private struct Annulus: View {
    let inner: CGFloat
    let outer: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: outer - inner)
            .frame(width: outer * 2, height: outer * 2)
    }
}

/// TaskPin (`components/TaskPin.dc.html`): 56 × 76 hit box, the pin anchor at (28, 46).
/// Hosted by `PinAnnotationView` (an `MLNAnnotationView`), so it is a real view that moves with the map and sits under
/// every SwiftUI overlay. The UIKit host is the accessibility element; this view is hidden from VoiceOver.
struct TaskPinView: View {
    let model: MapPinModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var priorityFill: Color { model.priority.fill }

    private var headFill: Color { model.isDone ? MapColors.doneHead : model.priority.fill }
    private var headGlyph: Color { model.isDone ? MapColors.doneGlyph : model.priority.onFill }

    /// Past pins fade to 45 % (70 % while selected); overdue ring, halo and time label stay at full opacity.
    private var bodyOpacity: Double { model.isPast && !model.isSelected ? 0.45 : (model.isPast ? 0.7 : 1) }
    private var timeOpacity: Double { model.isPast && !model.isOverdue ? 0.45 : 1 }

    private var timeColor: Color {
        if model.isOverdue { return Color.tk.danger }
        if model.isDone { return MapColors.doneGlyph }
        return Color.tk.textPrimary
    }

    private var headScale: CGFloat { model.isLifted || model.isSelected ? 1.25 : 1 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if model.isLifted {
                // Shadow left on the map under the lifted pin.
                Ellipse().fill(Color.black.opacity(0.28)).frame(width: 20, height: 8).offset(x: 18, y: 44)
            }
            head
                .frame(width: 56, height: 50)
                .scaleEffect(headScale, anchor: UnitPoint(x: 28 / 56, y: 48 / 50))
                .offset(y: model.isLifted ? -14 : 0)
            if let time = model.time, model.showsTime {
                Text(time)
                    .font(.custom("Inter-Bold", fixedSize: 11))
                    .monospacedDigit()
                    .foregroundStyle(timeColor)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Color.tk.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(model.isOverdue ? Color.tk.danger : Color.tk.border, lineWidth: 1))
                    .opacity(timeOpacity)
                    .frame(width: 56, alignment: .center)
                    .offset(y: 54)
            }
        }
        .frame(width: 56, height: 76, alignment: .topLeading)
        .animation(reduceMotion ? nil : Motion.emphasized(200), value: model.isSelected)
        .animation(reduceMotion ? nil : Motion.emphasized(Motion.short), value: model.isLifted)
        .accessibilityHidden(true)
    }

    private var head: some View {
        ZStack(alignment: .topLeading) {
            // Status ring + selection halo: their own layer, always full opacity.
            ZStack {
                if model.isSelected {
                    Annulus(inner: 18, outer: model.isOverdue ? 30 : 28, color: Color.tk.accent.opacity(0.55))
                }
                if model.isOverdue {
                    Annulus(inner: 20, outer: 23, color: Color.tk.danger)
                    Annulus(inner: 18, outer: 20, color: MapColors.pinRing)
                }
            }
            .frame(width: 36, height: 36)
            .offset(x: 10, y: 4)
            .frame(width: 56, height: 50, alignment: .topLeading)

            ZStack(alignment: .topLeading) {
                // One teardrop: the 2 pt ring and drop shadow are drawn around the head AND the tail together
                // (ring layer first), then the coloured tail and head on top, so the tail reads as part of the bubble.
                ZStack(alignment: .topLeading) {
                    // Tail ring: the 10 pt tail square grown by 2 pt on every side, rotated 45° about its centre.
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MapColors.pinRing)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(45))
                        .offset(x: 21, y: 31)
                    Circle()
                        .fill(MapColors.pinRing)
                        .frame(width: 40, height: 40)
                        .offset(x: 8, y: 2)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(model.isLifted ? 0.30 : 0.22), radius: model.isLifted ? 9 : 3, x: 0, y: model.isLifted ? 10 : 2)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(headFill)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(45))
                    .offset(x: 23, y: 33)
                Circle()
                    .fill(headFill)
                    .frame(width: 36, height: 36)
                    .overlay(glyph.foregroundStyle(headGlyph))
                    .offset(x: 10, y: 4)
                if let order = model.order {
                    Text("\(order)")
                        .font(.custom("Inter-Bold", fixedSize: 10))
                        .monospacedDigit()
                        .foregroundStyle(model.isDone ? Color.white : MapColors.onOrderBadge)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(model.isDone ? MapColors.doneOrderBadge : MapColors.orderBadge, in: Capsule())
                        .overlay(Capsule().strokeBorder(MapColors.pinRing, lineWidth: 2))
                        .offset(x: 36, y: 0)
                }
            }
            .frame(width: 56, height: 50, alignment: .topLeading)
            .opacity(bodyOpacity)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if model.isDone {
            MapIconView(icon: .check, size: 18, stroke: 3)
        } else {
            switch model.priority {
            case .high: MapIconView(icon: .flame, size: 18)
            case .medium: MapIconView(icon: .star, size: 18)
            case .low: MapIconView(icon: .leaf, size: 18, stroke: 2.4)
            }
        }
    }
}

/// StartMarker (`components/StartMarker.dc.html`): 40 pt black disc with a lime house + the "Start · address" label.
/// The annotation view is 240 × 72; the disc centre is (120, 20).
struct StartMarkerView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                Circle().fill(MapColors.startDisc)
                MapIconView(icon: .home, size: 20, stroke: 2.4).foregroundStyle(Color.tk.accent)
            }
            .frame(width: 40, height: 40)
            .background(Circle().fill(MapColors.startRing).frame(width: 46, height: 46))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)
            .offset(x: 100, y: 0)

            HStack(spacing: 6) {
                Text(MapFormat.tr("map_start")).foregroundStyle(Color.tk.accent)
                Text("· " + MapFormat.tr("map_start_address")).foregroundStyle(MapColors.startLabelText)
            }
            .font(.custom("Inter-SemiBold", fixedSize: 12))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(MapColors.startDisc, in: Capsule())
            .overlay(Capsule().strokeBorder(MapColors.startLabelBorder, lineWidth: 1.5))
            .offset(x: 4, y: 46)
        }
        .frame(width: 240, height: 72, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// Temporary pin of a long-press: lime halo rings, a pulsing ring and the dot (76 pt square, dot at the centre).
struct DroppedPinView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var dropped = false

    var body: some View {
        ZStack {
            Circle().fill(Color.tk.accent.opacity(0.22)).frame(width: 76, height: 76)
            Circle().fill(Color.tk.accent.opacity(0.45)).frame(width: 48, height: 48)
            if !reduceMotion {
                // Pulse: ring scale 1 → 2.2 and fade out, looping every 1200 ms.
                Circle()
                    .strokeBorder(Color.tk.accent, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(pulse ? 2.2 : 1)
                    .opacity(pulse ? 0 : 0.9)
            }
            Circle()
                .fill(Color.tk.accent)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(MapColors.startDisc, lineWidth: 3))
                .background(Circle().fill(MapColors.pinRing).frame(width: 26, height: 26))
                // Pin drop: falls 16 pt and fades in with a small overshoot (250 ms).
                .offset(y: dropped || reduceMotion ? 0 : -16)
                .opacity(dropped || reduceMotion ? 1 : 0)
        }
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.3)) { dropped = true }
            if !reduceMotion {
                withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
            }
        }
    }
}

/// Where the pin being moved used to be: a 36 pt dashed circle.
struct MoveGhostView: View {
    var body: some View {
        Circle()
            .fill(MapColors.ghostFill)
            .overlay(Circle().strokeBorder(Color.tk.textSecondary, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
    }
}
