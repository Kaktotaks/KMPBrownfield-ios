import SwiftUI
import Shared

/// Stats tab (§3.4). UI only: display-ready stats come from `StatsViewModel`. The large title is content.
@MainActor
struct StatsScreen: View {
    /// Owned by the screen; created once thanks to the autoclosure.
    @StateObject private var model: StatsViewModel

    init(model: @autoclosure @escaping () -> StatsViewModel) {
        _model = StateObject(wrappedValue: model())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("stats_title")
                    .tkStyle(.largeTitle)
                    .foregroundStyle(Color.tk.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                switch model.content {
                case .loading:
                    StatsSkeleton()
                case .error:
                    EmptyState(title: "error_title", message: "error_body", kind: .error) {
                        SecondaryButton(title: "retry", icon: .refresh) { model.retry() }
                    }
                case .loaded(let summary):
                    StatsContent(summary: summary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.tk.bg.ignoresSafeArea())
            .navigationTitle("stats_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            }
        }
    }
}

/// Loading: skeleton hero (r `xl`, h 152) + 4 skeleton tiles.
private struct StatsSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.sectionGap) {
            SkeletonBlock(shape: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)).frame(height: 152)
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: Spacing.sectionGap) {
                    SkeletonBlock(shape: RoundedRectangle(cornerRadius: Radius.l, style: .continuous)).frame(height: 96)
                    SkeletonBlock(shape: RoundedRectangle(cornerRadius: Radius.l, style: .continuous)).frame(height: 96)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.gutter)
    }
}

/// Animated values of the Stats screen (§4.1). All of them are driven from `play`.
private struct StatsAnimValues: Equatable {
    var progress = 0.0
    var total = 0.0
    var done = 0.0
    var active = 0.0
    var overdue = 0.0
    var bars = [0.0, 0.0, 0.0]
}

private struct StatsContent: View {
    let summary: StatsSummary

    @State private var anim = StatsAnimValues()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetProgress: Double { Double(summary.completionPercent) / 100 }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                hero
                HStack(spacing: Spacing.sectionGap) {
                    StatTile(label: "total", value: anim.total, target: summary.total, variant: .standard)
                    StatTile(label: "done", value: anim.done, target: summary.done, variant: .done)
                }
                HStack(spacing: Spacing.sectionGap) {
                    StatTile(label: "active", value: anim.active, target: summary.active, variant: .standard)
                    StatTile(label: "overdue", value: anim.overdue, target: summary.overdue, variant: .overdue)
                }
                priorityCard
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.gutter)
        }
        // Replay on every (re)entry of the tab; animate current -> new on data changes (S5).
        .onAppear { play(replay: true) }
        .onChange(of: summary) { _, _ in play(replay: false) }
    }

    /// Completion HeroCard. The ring (S1) and the percent text (S2) read ONE animated value, so the arc and the
    /// number can never drift apart; the last frame shows `completionPercent` exactly. VoiceOver reads the final
    /// value only, as one element.
    private var hero: some View {
        HeroCard(padding: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("completion").tkStyled(.overline).foregroundStyle(Color.tk.heroTextSecondary)
                    AnimatedCountText(
                        value: anim.progress,
                        target: targetProgress,
                        finalValue: summary.completionPercent,
                        scale: 100,
                        suffix: "%"
                    )
                    .tkStyle(.display)
                    .foregroundStyle(Color.tk.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    Text(L10n.format("n_of_m_done", summary.done, summary.total))
                        .tkStyle(.subhead15)
                        .foregroundStyle(Color.tk.heroTextSecondary)
                }
                Spacer(minLength: 8)
                CompletionRing(progress: anim.progress)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("completion"))
            .accessibilityValue(L10n.format("a11y_completion_value", summary.completionPercent, summary.done, summary.total))
        }
    }

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("by_priority").tkStyled(.overline).foregroundStyle(Color.tk.textSecondary)
            ForEach(Array(summary.priorityRows.enumerated()), id: \.offset) { index, row in
                PriorityBar(
                    label: row.priority.displayName,
                    countText: L10n.plural("n_tasks", row.count),
                    fraction: anim.bars[index],
                    fill: row.priority.barFill
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tk.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    /// S1-S5. `replay`: reset to 0 without animation, then 0 -> value (bars staggered 150 ms + index x 80 ms);
    /// otherwise animate from the current value to the new one with no delay. Snaps under Reduce Motion.
    private func play(replay: Bool) {
        if replay {
            var reset = Transaction(animation: nil)
            reset.disablesAnimations = true
            withTransaction(reset) { anim = StatsAnimValues() }
        }
        let summary = summary
        let reduce = reduceMotion
        // Next run-loop turn, so the reset above is rendered before the animation starts.
        DispatchQueue.main.async {
            withAnimation(reduce ? nil : Motion.emphasized(Motion.extraLong)) {
                anim.progress = Double(summary.completionPercent) / 100
            }
            withAnimation(reduce ? nil : Motion.emphasized(Motion.long)) {
                anim.total = Double(summary.total)
                anim.done = Double(summary.done)
                anim.active = Double(summary.active)
                anim.overdue = Double(summary.overdue)
            }
            for (index, row) in summary.priorityRows.enumerated() {
                let delay = replay ? Motion.stagger * index + 150 : 0
                withAnimation(reduce ? nil : Motion.emphasized(Motion.long, delayMs: delay)) {
                    anim.bars[index] = row.fraction
                }
            }
        }
    }
}
