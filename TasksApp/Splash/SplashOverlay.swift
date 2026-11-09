import SwiftUI
import UIKit
import Shared

/// Where the splash is. The root holds this for the whole cold start (no replay on foreground return).
enum SplashPhase {
    /// Overlay up, still holding (status bar is forced light by the root).
    case holding
    /// Exit started (content fading, circle reveal running).
    case exiting
    /// Overlay removed.
    case done
}

/// Measures time and latches the exit start. A plain reference type (not observed): `TimelineView` redraws every
/// frame anyway, and the latch must survive redraws. All values come from `MotionSpec.Splash`.
@MainActor
private final class SplashClock {
    /// The first frame that is actually produced defines t = 0, so main-thread work between view creation and the first
    /// draw (loading the shared framework, building the list) cannot eat the animation.
    private var start: Date?
    private(set) var readyAtMs: Int64?
    private(set) var exitStartMs: Int64?
    private var exitReported = false
    private var finishedReported = false

    private func elapsedMs(at date: Date, since start: Date) -> Int64 {
        Int64(max(0, date.timeIntervalSince(start)) * 1000)
    }

    func frame(at date: Date, isReady: Bool, reduceMotion: Bool) -> SplashFrame {
        let spec = MotionSpec.Splash.shared
        if start == nil { start = date }
        let elapsed = elapsedMs(at: date, since: start ?? date)
        if readyAtMs == nil, isReady { readyAtMs = elapsed }
        if exitStartMs == nil { exitStartMs = spec.exitStart(readyAt: readyAtMs, elapsed: elapsed) }
        return spec.frame(at: elapsed, exitStart: exitStartMs, reduceMotion: reduceMotion)
    }

    /// `true` once, when the exit start is first known.
    func takeExitReport() -> Bool {
        guard !exitReported, exitStartMs != nil else { return false }
        exitReported = true
        return true
    }

    func takeFinishedReport(_ frame: SplashFrame) -> Bool {
        guard !finishedReported, frame.finished else { return false }
        finishedReported = true
        return true
    }
}

/// The animated cold-start splash (SPLASH_HANDOFF §3). Sits above the root content; draws exactly what
/// `MotionSpec.Splash.frameAt` returns.
@MainActor
struct SplashOverlay: View {
    /// `true` once the task list's UI state is no longer `Loading` (Loaded or Error).
    let isReady: Bool
    /// Debug freeze (`-splashFrozenAtMs`): render this elapsed time with no clock and no auto-removal.
    var frozenAtMs: Int64?
    let onExit: () -> Void
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = SplashClock()

    private let spec = MotionSpec.Splash.shared

    var body: some View {
        Group {
            if let frozenAtMs {
                content(frame: spec.frame(at: frozenAtMs, exitStart: SplashLaunch.frozenExitStart(frozenAtMs), reduceMotion: reduceMotion))
            } else {
                TimelineView(.animation) { timeline in
                    let frame = clock.frame(at: timeline.date, isReady: isReady, reduceMotion: reduceMotion)
                    content(frame: frame)
                        .onAppear { report(frame) }
                        .onChange(of: timeline.date) { _, _ in report(frame) }
                }
            }
        }
        .ignoresSafeArea()
        // Swallow touches (overlay is never longer than MAX_HOLD + exit).
        .contentShape(Rectangle())
        .onTapGesture {}
        .accessibilityHidden(true)
    }

    /// Reports each transition once (latched in the clock), outside of the render pass.
    private func report(_ frame: SplashFrame) {
        let exit = clock.takeExitReport()
        let finished = clock.takeFinishedReport(frame)
        guard exit || finished else { return }
        DispatchQueue.main.async {
            if exit { onExit() }
            if finished { onFinished() }
        }
    }

    // MARK: - Drawing

    private func content(frame: SplashFrame) -> some View {
        GeometryReader { geo in
            let layout = Layout(size: geo.size, spec: spec)
            let reveal = CGFloat(frame.revealFraction) * layout.farthestCornerDistance
            ZStack(alignment: .topLeading) {
                SplashArt.background

                ZStack(alignment: .topLeading) {
                    SplashMark(frame: frame)
                        .position(x: layout.markCenter.x, y: layout.markCenter.y)

                    Text("splash_wordmark")
                        .tkStyle(.largeTitle)
                        .foregroundStyle(SplashArt.wordmark)
                        .lineLimit(1)
                        .frame(width: layout.size.width, height: layout.wordmarkHeight)
                        .opacity(Double(frame.wordmarkAlpha))
                        .position(x: layout.size.width / 2, y: layout.wordmarkCenterY + CGFloat(frame.wordmarkOffsetY))

                    Text("splash_caption")
                        .tkStyle(.subhead15)
                        .foregroundStyle(SplashArt.caption)
                        .lineLimit(1)
                        .frame(width: layout.size.width, height: layout.captionHeight)
                        .opacity(Double(frame.captionAlpha))
                        .position(x: layout.size.width / 2, y: layout.captionCenterY + CGFloat(frame.captionOffsetY))
                }
                .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
                .scaleEffect(CGFloat(frame.contentScale), anchor: layout.discAnchor)
                .opacity(Double(frame.contentAlpha))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: 2 * reveal, height: 2 * reveal)
                            .position(layout.discCenter)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .opacity(Double(frame.overlayAlpha))
        }
        // The design geometry is fixed (block 212 pt), so the texts do not follow Dynamic Type.
        .dynamicTypeSize(.large)
    }

    /// Screen geometry from the shared spec constants.
    private struct Layout {
        let size: CGSize
        let blockTop: CGFloat
        let markOrigin: CGPoint
        let discCenter: CGPoint
        let markCenter: CGPoint
        let wordmarkCenterY: CGFloat
        let captionCenterY: CGFloat
        let farthestCornerDistance: CGFloat
        let discAnchor: UnitPoint
        /// Line heights of the `largeTitle` (38) and `subhead15` (20) tokens.
        let wordmarkHeight = TKTextStyle.largeTitle.lineHeight
        let captionHeight = TKTextStyle.subhead15.lineHeight

        init(size: CGSize, spec: MotionSpec.Splash) {
            self.size = size
            let markWidth = CGFloat(spec.MARK_WIDTH)
            let markHeight = CGFloat(spec.MARK_HEIGHT)
            blockTop = (size.height - CGFloat(spec.BLOCK_HEIGHT)) / 2
            markOrigin = CGPoint(x: (size.width - markWidth) / 2, y: blockTop)
            markCenter = CGPoint(x: markOrigin.x + markWidth / 2, y: markOrigin.y + markHeight / 2)
            let inMark = spec.discCenterInMark()
            discCenter = CGPoint(x: markOrigin.x + CGFloat(inMark.first!.floatValue), y: markOrigin.y + CGFloat(inMark.second!.floatValue))
            wordmarkCenterY = blockTop + CGFloat(spec.WORDMARK_TOP) + TKTextStyle.largeTitle.lineHeight / 2
            captionCenterY = blockTop + CGFloat(spec.CAPTION_TOP) + TKTextStyle.subhead15.lineHeight / 2
            farthestCornerDistance = hypot(max(discCenter.x, size.width - discCenter.x), max(discCenter.y, size.height - discCenter.y)) + 2
            discAnchor = UnitPoint(x: discCenter.x / max(size.width, 1), y: discCenter.y / max(size.height, 1))
        }
    }
}

/// Observes the task list's ViewModel so only the splash (not the whole root) re-renders on list changes.
@MainActor
struct SplashHost: View {
    @ObservedObject var list: TaskListViewModel
    var frozenAtMs: Int64?
    let onExit: () -> Void
    let onFinished: () -> Void

    private var isReady: Bool {
        if case .loading = list.content { return false }
        return true
    }

    var body: some View {
        SplashOverlay(isReady: isReady, frozenAtMs: frozenAtMs, onExit: onExit, onFinished: onFinished)
    }
}
