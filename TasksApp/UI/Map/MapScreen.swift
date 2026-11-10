import SwiftUI
import Shared

/// Map tab (handoff §3.4 layering). One ZStack, bottom to top:
///   0  the map: tiles, route, start, pins, dropped pin, move ghost: one clipped UIKit view;
///   10 day selector / move banner, status chips, move card;
///   20 route sheet (above the tab bar, which the system draws over this view's bottom);
///   40 task sheet / new-task sheet, presented with `.sheet` (they cover the tab bar and don't dim the map).
/// No annotation can draw above an overlay: pins are subviews of the map view, a single sibling at z 0.
struct MapScreen: View {
    @ObservedObject var model: MapViewModel
    /// False while the splash holds: the map view (and its tile requests) is only created once the splash is gone, so
    /// loading tiles can never delay the splash exit.
    let isMapEnabled: Bool
    @Binding var barHidden: Bool

    @State private var actions = MapActions()
    @State private var reloadToken = 0

    private static let selectorHeight: CGFloat = 48
    private static let bannerHeight: CGFloat = 64
    private static let moveCardHeight: CGFloat = 100

    /// Height of the custom tab bar that floats over the bottom of this full-height screen. The overlays end above
    /// it; the map continues under it (and the home indicator), so it shows through around the floating sheets'
    /// rounded corners. All bottom camera paddings include bar + home indicator, so the visible band stays put.
    @Environment(\.mapBarHeight) private var barHeight

    var body: some View {
        GeometryReader { geo in
            let safe = geo.safeAreaInsets
            let bleed = barHeight + safe.bottom
            let layout = MapLayout(
                top: safe.top + 4 + Self.selectorHeight + 24,
                fitBottom: bleed + RouteSheetView.collapsedHeight + 24,
                taskSheetBottom: bleed + 560,
                draftSheetBottom: bleed + 700,
                moveTop: safe.top + 4 + Self.bannerHeight + 16,
                moveBottom: bleed + 16 + Self.moveCardHeight + 16
            )
            ZStack(alignment: .bottom) {
                topOverlays()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(10)

                if model.state.move != nil {
                    MovePlaceCardView(address: model.moveAddress)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .zIndex(10)
                        .accessibilitySortPriority(2)
                } else if showsRouteSheet {
                    RouteSheetView(
                        model: model,
                        availableHeight: geo.size.height - barHeight - 8,
                        onRecenter: { model.recenter() }
                    )
                    .zIndex(20)
                    .accessibilitySortPriority(2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height - barHeight)
            // Full screen, under the status bar and the tab bar. A background never changes the layout size, so the
            // overlays above keep the safe-area frame.
            .background(alignment: .bottom) {
                mapLayer(layout)
                    .frame(width: geo.size.width, height: geo.size.height + safe.top + safe.bottom)
                    .offset(y: bleed)
                    .accessibilitySortPriority(1)
            }
        }
        .background(Color.tk.bg)
        .sheet(isPresented: taskSheetBinding) {
            if let sheet = model.taskSheet {
                TaskMapSheet(model: model, sheet: sheet)
                    .mapSheetChrome(height: 560)
            }
        }
        .sheet(isPresented: newTaskBinding) {
            if let draft = model.draft {
                NewTaskAtLocationSheet(model: model, draft: draft)
                    .mapSheetChrome(height: 700)
            }
        }
        .onAppear { wireActions() }
        .onChange(of: model.taskSheet != nil || model.draft != nil) { _, open in barHidden = open }
        .onDisappear { barHidden = false }
    }

    private var showsRouteSheet: Bool {
        model.state.selectedStop == nil && model.state.newTaskDraft == nil
    }

    // MARK: - Layers

    @ViewBuilder
    private func mapLayer(_ layout: MapLayout) -> some View {
        if isMapEnabled {
            ColorSchemeReader { dark in
                MapLibreMapView(
                    state: model.renderState(dark: dark, layout: layout),
                    camera: model.cameraRequest,
                    reloadToken: reloadToken,
                    actions: actions,
                    accessibilityMapLabel: MapFormat.tr("map_a11y_map"),
                    addHereLabel: MapFormat.tr("map_a11y_add_here")
                )
            }
        } else {
            Color.tk.bg
        }
    }

    private func topOverlays() -> some View {
        VStack(spacing: 10) {
            if model.state.move != nil {
                MovePinBannerView(onCancel: { model.cancelMove() }, onDone: { model.confirmMove() })
                    .accessibilitySortPriority(3)
            } else if model.state.newTaskDraft == nil {
                DaySelectorView(model: model)
                    .padding(.horizontal, 16)
                    .accessibilitySortPriority(3)
            }
            if let chip = model.chip, model.state.newTaskDraft == nil, model.state.move == nil {
                MapStatusChipView(chip: chip, text: model.chipText) {
                    model.retry()
                    reloadToken += 1
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, model.state.move != nil ? 16 : 0)
        .padding(.top, 4)
        .animation(Motion.emphasized(Motion.medium), value: model.chip)
    }

    // MARK: - Sheets

    private var taskSheetBinding: Binding<Bool> {
        Binding(
            get: { model.isTaskSheetPresented },
            set: { presented in
                // Swipe-down dismissal deselects the pin (not while moving it, or when state hides the sheet).
                if !presented, model.state.move == nil, model.state.selectedStop != nil, model.state.newTaskDraft == nil {
                    model.clearSelection()
                }
            }
        )
    }

    private var newTaskBinding: Binding<Bool> {
        Binding(
            get: { model.state.newTaskDraft != nil },
            set: { presented in
                if !presented, model.state.newTaskDraft != nil { model.cancelNewTask() }
            }
        )
    }

    private func wireActions() {
        actions.onSelect = { [weak model] id in model?.selectTask(id) }
        actions.onLongPress = { [weak model] coord in model?.longPress(coord) }
        actions.onAddHere = { [weak model] coord in model?.addTaskHere(at: coord) }
        actions.onBackgroundTap = { [weak model] in
            guard let model else { return }
            if model.state.selectedStop != nil {
                model.clearSelection()
            } else if RouteSheetMetrics.collapsesOnMapTap(
                expanded: model.state.sheetExpanded,
                hasSelection: false,
                isMoving: model.state.move != nil,
                hasDraft: model.state.newTaskDraft != nil
            ) {
                model.setSheetExpanded(false)
            }
        }
        actions.onMoveCenter = { [weak model] coord in model?.updateMoveCandidate(coord) }
        actions.onOffline = { [weak model] offline in model?.reportTilesOffline(offline) }
    }
}

/// Sheet chrome shared by the two map sheets: a fixed detent plus `.large`, the map stays interactive behind them.
private extension View {
    func mapSheetChrome(height: CGFloat) -> some View {
        self
            .presentationDetents([.height(height), .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .height(height)))
            .presentationDragIndicator(.visible)
            // No fixed corner radius: the system inset sheet uses corners concentric with the device's screen corners.
            .presentationBackground(Color.tk.bg)
    }
}

/// Reads the colour scheme so the style (light / dark JSON) follows the system appearance.
private struct ColorSchemeReader<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: (Bool) -> Content

    var body: some View { content(colorScheme == .dark) }
}

private struct MapBarHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }

extension EnvironmentValues {
    /// Set by `RootView`: the height of the tab bar that floats over the bottom of the Map screen.
    var mapBarHeight: CGFloat {
        get { self[MapBarHeightKey.self] }
        set { self[MapBarHeightKey.self] = newValue }
    }
}
