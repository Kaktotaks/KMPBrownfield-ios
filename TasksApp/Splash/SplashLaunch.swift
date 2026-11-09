import Foundation
import Shared

/// Launch-argument switches for the splash.
enum SplashLaunch {
    /// `-disableSplash`: no overlay at all (UI tests, screenshot scripts).
    static var isDisabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-disableSplash")
    }

    /// Debug-only `-splashFrozenAtMs <N>`: render the overlay at the fixed elapsed time N with no clock and no
    /// auto-removal (design screenshots). The exit starts at the earliest allowed moment, so `1820` shows the
    /// frame 320 ms into the exit.
    static var frozenAtMs: Int64? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-splashFrozenAtMs"), args.indices.contains(index + 1) else { return nil }
        return Int64(args[index + 1])
        #else
        return nil
        #endif
    }

    /// Exit start of a frozen frame: the minimum hold if N is past it, otherwise still holding.
    static func frozenExitStart(_ elapsed: Int64) -> Int64? {
        let minHold = MotionSpec.Splash.shared.MIN_HOLD_MS
        return elapsed >= minHold ? minHold : nil
    }
}
