import SwiftUI
import Shared

/// Priority badge of the map sheets: solid (`priority.fill`), or the tinted "past" variant with a border so the text
/// keeps its contrast (opacity is never applied to text in sheets, §5).
struct MapPriorityBadge: View {
    let priority: Priority
    var faded = false
    var large = false

    var body: some View {
        let tint = MapColors.fadedBadge(priority)
        Text(priority.displayName)
            .font(.custom("Inter-Bold", fixedSize: large ? 12 : 11))
            .textCase(.uppercase)
            .tracking(0.04 * (large ? 12 : 11))
            .foregroundStyle(faded ? tint.text : priority.onFill)
            .padding(.horizontal, faded ? (large ? 9 : 7) : (large ? 10 : 8))
            .padding(.vertical, faded ? (large ? 3 : 2) : (large ? 4 : 3))
            .background(faded ? tint.fill : priority.fill, in: RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
            .overlay {
                if faded { RoundedRectangle(cornerRadius: Radius.xs, style: .continuous).strokeBorder(tint.border, lineWidth: 1) }
            }
            .fixedSize()
    }
}

/// One row of the full list (`RouteStopRow`): 28 pt badge + connector, time line, title, address, priority, leg.
struct RouteStopRowView: View {
    let row: MapStopRow
    let hasNext: Bool
    let onTap: () -> Void

    private var secondary: Color { row.isPast ? Color.tk.textTertiary : Color.tk.textSecondary }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                badge
                    .opacity(row.isPast && !row.isOverdue ? 0.45 : 1)
                if hasNext {
                    Capsule().fill(MapColors.connector).frame(width: 2).frame(minHeight: 12).padding(.top, 4)
                }
            }
            .frame(width: 28)
            .accessibilityHidden(true)

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.timeLine)
                                .font(.custom("Inter-Bold", size: 13, relativeTo: .footnote))
                                .monospacedDigit()
                                .foregroundStyle(row.isOverdue ? Color.tk.danger : (row.isDone || row.isPast ? Color.tk.textTertiary : Color.tk.textSecondary))
                            Text(row.title)
                                .font(.custom("Inter-SemiBold", size: 16, relativeTo: .body))
                                .strikethrough(row.isDone)
                                .foregroundStyle(row.isDone || row.isPast ? Color.tk.textTertiary : Color.tk.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text(row.address)
                                .font(.custom("Inter-Regular", size: 13, relativeTo: .footnote))
                                .foregroundStyle(Color.tk.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if let priority = row.priority { MapPriorityBadge(priority: priority, faded: row.isPast) }
                    }
                    if let leg = row.legText {
                        HStack(spacing: 6) {
                            MapIconView(icon: .car, size: 14)
                            Text(leg).font(.custom("Inter-Medium", size: 12, relativeTo: .caption)).monospacedDigit()
                        }
                        .foregroundStyle(secondary)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, row.legText == nil ? 0 : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .accessibilityAddTraits(row.kind == .stop ? .isButton : .isStaticText)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var badge: some View {
        switch row.kind {
        case .start:
            Circle().fill(MapColors.startDisc)
                .overlay(MapIconView(icon: .home, size: 15, stroke: 2.6).foregroundStyle(Color.tk.accent))
                .overlay(Circle().strokeBorder(MapColors.startLabelBorder, lineWidth: 1.5))
                .frame(width: 28, height: 28)
        case .stop:
            if row.isDone {
                Circle().fill(Color.tk.accent).frame(width: 28, height: 28)
                    .overlay(MapIconView(icon: .check, size: 15, stroke: 3.2).foregroundStyle(Color.tk.onAccent))
            } else if row.isOverdue {
                Circle().fill(Color.tk.surface).frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Color.tk.danger, lineWidth: 2))
                    .overlay(orderText.foregroundStyle(Color.tk.danger))
            } else if row.order != nil {
                Circle().fill(MapColors.orderBadge).frame(width: 28, height: 28)
                    .overlay(orderText.foregroundStyle(MapColors.onOrderBadge))
            } else {
                Circle().fill(Color.tk.surface2).frame(width: 28, height: 28)
                    .overlay(MapIconView(icon: .pin, size: 15).foregroundStyle(Color.tk.textSecondary))
            }
        }
    }

    private var orderText: some View {
        Text(row.order.map(String.init) ?? "")
            .font(.custom("Inter-Bold", size: 13, relativeTo: .footnote))
            .monospacedDigit()
    }
}

/// Pure geometry of the route sheet drag (detents 176 / 640 capped to the space above the tab bar). Kept free of
/// SwiftUI so it can be unit-tested.
enum RouteSheetMetrics {
    static let collapsedHeight: CGFloat = 176
    static let expandedHeight: CGFloat = 640

    static func expandedTarget(availableHeight: CGFloat) -> CGFloat {
        min(expandedHeight, max(collapsedHeight, availableHeight - 24))
    }

    /// Live height while dragging: follows the finger, clamped to the two detents.
    static func liveHeight(start: CGFloat, translation: CGFloat, expanded: CGFloat) -> CGFloat {
        min(expanded, max(collapsedHeight, start - translation))
    }

    /// 0 collapsed ... 1 expanded; drives the cross-fade between the next-stop card and the list.
    static func progress(height: CGFloat, expanded: CGFloat) -> CGFloat {
        let span = expanded - collapsedHeight
        guard span > 0 else { return 0 }
        return min(1, max(0, (height - collapsedHeight) / span))
    }

    /// Where the sheet comes to rest with the drag's velocity: past the midpoint of the detents it expands.
    static func shouldExpand(start: CGFloat, predictedTranslation: CGFloat, expanded: CGFloat) -> Bool {
        (start - predictedTranslation) > (collapsedHeight + expanded) / 2
    }
}

/// Route sheet: a custom draggable sheet above the tab bar (detents 176 / 640). Opens collapsed (summary + next stop);
/// the full list is the accessible equivalent of the map.
///
/// Drag performance: the sheet content is laid out ONCE at the expanded height and the drag only changes an `offset`
/// and two opacities. The header, next card, list and empty card are separate `View`s that observe the model
/// themselves, so SwiftUI skips their bodies while `liveHeight` changes every frame (before, each frame recomputed
/// `model.rows`, relaid out the list, swapped the next card for a fresh `ScrollView` and re-rendered a shadow over
/// the whole content).
struct RouteSheetView: View {
    @ObservedObject var model: MapViewModel
    /// Available height above the tab bar (the expanded detent is capped to it).
    let availableHeight: CGFloat
    let onRecenter: () -> Void

    static let collapsedHeight = RouteSheetMetrics.collapsedHeight
    static let expandedHeight = RouteSheetMetrics.expandedHeight

    @State private var dragStartHeight: CGFloat?
    @State private var liveHeight: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var expandedTarget: CGFloat { RouteSheetMetrics.expandedTarget(availableHeight: availableHeight) }
    private var restingHeight: CGFloat { model.state.sheetExpanded ? expandedTarget : Self.collapsedHeight }
    private var height: CGFloat { liveHeight ?? restingHeight }

    var body: some View {
        let expanded = expandedTarget
        let progress = RouteSheetMetrics.progress(height: height, expanded: expanded)
        let isEmpty = model.isEmptyDay
        let isExpanded = model.state.sheetExpanded
        let sheetShape = UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl, style: .continuous)

        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Capsule().fill(MapColors.grabber).frame(width: 36, height: 5).padding(.top, 6)
                    .frame(height: 11)
                RouteSheetHeader(model: model, onRecenter: onRecenter).padding(.horizontal, 16).padding(.top, 8)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityElement(children: .contain)

            ZStack(alignment: .top) {
                if isEmpty {
                    RouteEmptyCard().padding(.horizontal, 16).padding(.top, 12)
                } else {
                    RouteNextCardSlot(model: model)
                        .opacity(1 - progress)
                        .allowsHitTesting(progress < 0.5)
                        .accessibilityHidden(isExpanded)
                    RouteListSlot(model: model)
                        .opacity(progress)
                        .allowsHitTesting(isExpanded)
                        .accessibilityHidden(!isExpanded)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        // Laid out at the full detent; only the offset below follows the finger.
        .frame(height: expanded, alignment: .top)
        .background {
            // The shadow lives on a plain shape (cheap), not on the whole content.
            sheetShape.fill(Color.tk.bg)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.6 : 0.12), radius: 12, x: 0, y: -6)
        }
        .overlay(alignment: .top) {
            sheetShape
                .strokeBorder(Color.tk.border, lineWidth: 1)
                .mask(alignment: .top) { Rectangle().frame(height: 2) }
        }
        .offset(y: expanded - height)
        // Stationary window the sheet slides in: clips what is below the tab bar, leaves room above for the shadow.
        .frame(height: expanded, alignment: .top)
        .mask { Rectangle().padding(.top, -24) }
        .animation(reduceMotion || liveHeight != nil ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: model.state.sheetExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(MapFormat.tr("map_a11y_route_sheet"))
    }

    // MARK: - Drag (velocity-aware snap between the two detents)

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let start = dragStartHeight ?? restingHeight
                dragStartHeight = start
                liveHeight = RouteSheetMetrics.liveHeight(start: start, translation: value.translation.height, expanded: expandedTarget)
            }
            .onEnded { value in
                let start = dragStartHeight ?? restingHeight
                let expand = RouteSheetMetrics.shouldExpand(start: start, predictedTranslation: value.predictedEndTranslation.height, expanded: expandedTarget)
                dragStartHeight = nil
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                    liveHeight = nil
                    model.setSheetExpanded(expand)
                }
            }
    }
}

// MARK: - Isolated content (each observes the model itself, so a drag frame does not re-run their bodies)

private struct RouteSheetHeader: View {
    @ObservedObject var model: MapViewModel
    let onRecenter: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.sheetHeading)
                    .tkStyle(.title)
                    .foregroundStyle(Color.tk.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Text(model.summaryText)
                    .font(.custom("Inter-Medium", size: 14, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(Color.tk.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if !model.isEmptyDay {
                Button(action: onRecenter) {
                    HStack(spacing: 6) {
                        MapIconView(icon: .locate, size: 18)
                        Text(MapFormat.tr("map_recenter")).font(.custom("Inter-SemiBold", size: 14, relativeTo: .subheadline))
                    }
                    .foregroundStyle(Color.tk.textPrimary)
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
                    .frame(minHeight: 40)
                    .overlay(Capsule().strokeBorder(Color.tk.textPrimary, lineWidth: 1.5))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityAction(named: Text(MapFormat.tr(model.state.sheetExpanded ? "map_a11y_collapse" : "map_a11y_expand"))) {
            model.setSheetExpanded(!model.state.sheetExpanded)
        }
    }

}

private struct RouteNextCardSlot: View {
    @ObservedObject var model: MapViewModel

    var body: some View {
        if let next = model.next {
            nextCard(next).padding(.horizontal, 16).padding(.top, 12)
        }
    }

    private func nextCard(_ next: MapNextStop) -> some View {
        Button { model.selectTask(next.taskId) } label: {
            HStack(spacing: 12) {
                Text(next.order.map(String.init) ?? "")
                    .font(.custom("Inter-Bold", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.tk.onInverse)
                    .frame(width: 28, height: 28)
                    .background(Color.tk.inverse, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(next.line)
                        .font(.custom("Inter-Bold", size: 13, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundStyle(Color.tk.textSecondary)
                    Text(next.title)
                        .font(.custom("Inter-SemiBold", size: 16, relativeTo: .body))
                        .foregroundStyle(Color.tk.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                MapPriorityBadge(priority: next.priority)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(next.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

}

private struct RouteListSlot: View {
    @ObservedObject var model: MapViewModel

    var body: some View { list }

    private var list: some View {
        let rows = model.rows
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    RouteStopRowView(row: row, hasNext: row.legText != nil && index + 1 < rows.count) {
                        if let id = row.taskId { model.selectTask(id) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(MapFormat.tr("map_a11y_stops_list"))
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(!model.state.sheetExpanded)
    }

}

private struct RouteEmptyCard: View {
    var body: some View { emptyCard }

    private var emptyCard: some View {
        HStack(spacing: 14) {
            MapIconView(icon: .pinAdd, size: 22)
                .foregroundStyle(Color.tk.textSecondary)
                .frame(width: 44, height: 44)
                .background(Color.tk.surface2, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(MapFormat.tr("map_empty_title")).font(.custom("Inter-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(Color.tk.textPrimary)
                Text(MapFormat.tr("map_empty_message")).tkStyle(.subhead).foregroundStyle(Color.tk.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }

}
