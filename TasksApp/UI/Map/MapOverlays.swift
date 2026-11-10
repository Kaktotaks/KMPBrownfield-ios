import SwiftUI

/// Floating controls above the map (z 10): day selector, move banner + card, status chip.

private extension Font {
    static func inter(_ name: String, _ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(name, size: size, relativeTo: style)
    }
}

/// Shadow of the floating pills / cards: 0 4 14 black 12 % (light) / 50 % (dark).
private struct FloatingShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat = 7
    var y: CGFloat = 4

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: radius, x: 0, y: y)
    }
}

/// DaySelector: one pill ‹ Today · Wed 4 Nov ›. Tapping the label opens the system date picker.
struct DaySelectorView: View {
    @ObservedObject var model: MapViewModel
    @State private var picked = Date()

    var body: some View {
        HStack(spacing: 2) {
            stepButton(.chevronLeft, label: MapFormat.tr("map_a11y_prev_day")) { model.previousDay() }
            Button {
                picked = model.dayDate
                model.isPickingDay = true
            } label: {
                HStack(spacing: 6) {
                    if let relative = model.relativeDay {
                        Text(relative).font(.inter("Inter-Bold", 15, relativeTo: .subheadline))
                        Text("· " + model.dayText)
                            .font(.inter("Inter-Medium", 15, relativeTo: .subheadline))
                            .foregroundStyle(Color.tk.textSecondary)
                    } else {
                        Text(model.dayText).font(.inter("Inter-Bold", 15, relativeTo: .subheadline))
                    }
                }
                .foregroundStyle(Color.tk.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .frame(minWidth: 168, minHeight: 44)
                .background(Color.tk.surface2, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.dayAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .popover(isPresented: $model.isPickingDay) {
                DatePicker("due_date", selection: Binding(get: { picked }, set: { picked = $0; model.selectDay($0) }),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Color.tk.textPrimary)
                    .frame(width: 320, height: 340)
                    .padding(Spacing.s12)
                    .presentationCompactAdaptation(.popover)
            }
            stepButton(.chevronRight, label: MapFormat.tr("map_a11y_next_day")) { model.nextDay() }
        }
        .padding(2)
        .frame(height: 48)
        .background(Color.tk.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.tk.border, lineWidth: 1))
        .modifier(FloatingShadow())
        .accessibilityElement(children: .contain)
    }

    private func stepButton(_ icon: MapIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MapIconView(icon: icon, size: 20, stroke: 2.4)
                .foregroundStyle(Color.tk.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// MovePinBanner: black banner "Drag the pin to a new place" · Cancel · Done.
struct MovePinBannerView: View {
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            MapIconView(icon: .move, size: 20).foregroundStyle(Color.tk.accent)
            Text(MapFormat.tr("map_move_banner"))
                .font(.inter("Inter-SemiBold", 15, relativeTo: .subheadline))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onCancel) {
                Text(MapFormat.tr("map_cancel"))
                    .font(.inter("Inter-SemiBold", 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(MapColors.bannerButton, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Button(action: onDone) {
                Text(MapFormat.tr("map_move_done"))
                    .font(.inter("Inter-Bold", 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.tk.onAccent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Color.tk.accent, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding([.vertical, .trailing], 12)
        .background(MapColors.bannerSurface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(MapColors.bannerBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 9, x: 0, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// "New place" card of the move mode.
struct MovePlaceCardView: View {
    let address: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MapFormat.tr("map_move_new_place")).tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
            Text(address)
                .font(.inter("Inter-SemiBold", 17, relativeTo: .headline))
                .foregroundStyle(Color.tk.textPrimary)
                .lineLimit(2)
            Text(MapFormat.tr("map_move_hint")).tkStyle(.caption).foregroundStyle(Color.tk.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .modifier(FloatingShadow(radius: 9, y: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(MapFormat.tr("map_a11y_move_center", address) + ". " + MapFormat.tr("map_move_hint")))
    }
}

/// Status chip: building route / routing failed / no connection (+ Retry). Announced politely.
struct MapStatusChipView: View {
    let chip: MapChip
    let text: String
    let onRetry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(text)
                .font(.inter("Inter-SemiBold", 13, relativeTo: .footnote))
                .foregroundStyle(Color.tk.textPrimary)
                .padding(.trailing, chip == .offline ? 0 : 4)
            if chip == .offline {
                Button(action: onRetry) {
                    Text(MapFormat.tr("map_retry"))
                        .font(.inter("Inter-Bold", 13, relativeTo: .footnote))
                        .foregroundStyle(Color.tk.onInverse)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 28)
                        .background(Color.tk.inverse, in: Capsule())
                        .frame(minHeight: Spacing.minTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 36)
        .background(Color.tk.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.tk.border, lineWidth: 1))
        .modifier(FloatingShadow(radius: 6))
        .accessibilityElement(children: chip == .offline ? .contain : .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var icon: some View {
        switch chip {
        case .loading:
            ZStack {
                Circle().stroke(Color.tk.border, lineWidth: 3)
                Circle().trim(from: 0, to: 0.25)
                    .stroke(Color.tk.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(spinning ? 360 : 0))
            }
            .frame(width: 16, height: 16)
            .padding(1.5)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spinning = true }
            }
        case .failed:
            MapIconView(icon: .alert, size: 16, stroke: 2.4).foregroundStyle(Color.tk.danger)
        case .offline:
            MapIconView(icon: .wifiOff, size: 16, stroke: 2.3).foregroundStyle(Color.tk.danger)
        }
    }
}
