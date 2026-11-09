import SwiftUI
import UIKit
import Shared

/// Editor "Time" row (optional, with a "No time" state): looks like `DateField`; opens the system hour / minute wheel.
struct EditorTimeField: View {
    @ObservedObject var model: TaskEditorViewModel
    @State private var isPicking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MapFormat.tr("map_editor_time")).tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
            Button {
                model.setDefaultTimeIfNeeded()
                isPicking = true
            } label: {
                HStack {
                    Text(model.timeText)
                        .tkStyle(.body)
                        .monospacedDigit()
                        .foregroundStyle(model.hasTime ? Color.tk.textPrimary : Color.tk.textSecondary)
                    Spacer(minLength: 8)
                    MapIconView(icon: .clock, size: 20).foregroundStyle(Color.tk.textPrimary)
                }
                .padding(.horizontal, 14)
                .modifier(FieldChrome(focused: false, invalid: false, minHeight: 48))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(MapFormat.tr("map_editor_time")), \(model.timeText)"))
            .accessibilityAddTraits(.isButton)
            .popover(isPresented: $isPicking) {
                VStack(spacing: 8) {
                    DatePicker("", selection: model.timeDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(width: 240, height: 160)
                    Button {
                        model.clearTime()
                        isPicking = false
                    } label: {
                        Text(MapFormat.tr("map_no_time"))
                            .tkStyle(.bodyMedium)
                            .foregroundStyle(Color.tk.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.s12)
                .frame(width: 264)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

/// Editor "Place" row: the address, or "Add place". Tapping it opens the address search: this is also the accessible
/// alternative to long-press and drag on the map.
struct EditorPlaceField: View {
    @ObservedObject var model: TaskEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MapFormat.tr("map_editor_place")).tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
            Button { model.openPlaceSearch() } label: {
                HStack(spacing: 10) {
                    Text(model.placeAddress ?? MapFormat.tr("map_add_place"))
                        .tkStyle(.body)
                        .foregroundStyle(model.placeAddress == nil ? Color.tk.textSecondary : Color.tk.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    MapIconView(icon: .pin, size: 20).foregroundStyle(Color.tk.textPrimary)
                }
                .padding(.horizontal, 14)
                .modifier(FieldChrome(focused: false, invalid: false, minHeight: 48))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(model.placeAddress.map { "\(MapFormat.tr("map_editor_place")), \($0)" } ?? MapFormat.tr("map_add_place")))
            .accessibilityHint(Text(MapFormat.tr(model.placeAddress == nil ? "map_add_place" : "map_change_place")))
            .accessibilityAddTraits(.isButton)
            .sheet(item: $model.placeSearch) { search in
                PlaceSearchSheet(
                    search: search,
                    currentAddress: model.placeAddress,
                    onPick: { model.choosePlace($0) },
                    onClear: { model.clearPlace() },
                    onCancel: { model.closePlaceSearch() }
                )
            }
        }
    }
}

/// Address search (shared `Geocoder.search` through `PlaceSearchViewModel`: 500 ms debounce, ≥ 3 characters).
struct PlaceSearchSheet: View {
    @ObservedObject var search: PlaceSearchModel
    let currentAddress: String?
    let onPick: (Place) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private var state: PlaceSearchUiState { search.state }
    private var needsMoreCharacters: Bool { query.trimmingCharacters(in: .whitespaces).count < Int(PlaceSearchViewModel.companion.MIN_QUERY_LENGTH) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(MapFormat.tr("map_search_title"))
                    .tkStyle(.sheetTitle)
                    .foregroundStyle(Color.tk.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button(action: onCancel) {
                        Text(MapFormat.tr("map_cancel"))
                            .tkStyle(.bodyMedium)
                            .foregroundStyle(Color.tk.textPrimary)
                            .frame(minHeight: Spacing.minTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, 20)
            .frame(minHeight: 48)

            HStack(spacing: 10) {
                MapIconView(icon: .pin, size: 18).foregroundStyle(Color.tk.textSecondary)
                TextField("", text: $query, prompt: Text(MapFormat.tr("map_search_address")).foregroundStyle(Color.tk.textSecondary))
                    .tkStyle(.body)
                    .foregroundStyle(Color.tk.textPrimary)
                    .tint(Color.tk.textPrimary)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        MapIconView(icon: .close, size: 16).foregroundStyle(Color.tk.textSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle().inset(by: -8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("search_clear")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.tk.surface2, in: Capsule())
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if currentAddress != nil {
                        Button(action: onClear) {
                            HStack(spacing: 10) {
                                MapIconView(icon: .trash, size: 18)
                                Text(MapFormat.tr("map_clear_place")).tkStyle(.bodyStrong)
                            }
                            .foregroundStyle(Color.tk.onDangerContainer)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .background(Color.tk.dangerContainer, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }
                    results
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tk.bg)
        .onChange(of: query) { _, value in search.send { $0.onQueryChange(value: value) } }
        .onAppear { focused = true }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.xl)
        .presentationBackground(Color.tk.bg)
    }

    @ViewBuilder
    private var results: some View {
        if needsMoreCharacters {
            note(MapFormat.tr("map_search_hint"))
        } else if state.failed {
            VStack(alignment: .leading, spacing: 8) {
                note(MapFormat.tr("map_search_failed"))
                Button { search.send { $0.onRetry() } } label: {
                    Text(MapFormat.tr("map_retry")).tkStyle(.bodyStrong).foregroundStyle(Color.tk.textPrimary)
                        .frame(minHeight: Spacing.minTarget).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if state.isSearching && state.results.isEmpty {
            ProgressView().tint(Color.tk.textPrimary).frame(maxWidth: .infinity).padding(.top, 24)
        } else if state.noResults {
            note(MapFormat.tr("map_search_none"))
        } else {
            ForEach(Array(state.results.enumerated()), id: \.offset) { _, place in
                Button { onPick(place) } label: {
                    HStack(spacing: 12) {
                        MapIconView(icon: .pin, size: 18).foregroundStyle(Color.tk.textSecondary)
                        Text(place.address)
                            .tkStyle(.body)
                            .foregroundStyle(Color.tk.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                Divider().overlay(Color.tk.border)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).tkStyle(.subhead).foregroundStyle(Color.tk.textSecondary).padding(.top, 8)
    }
}
