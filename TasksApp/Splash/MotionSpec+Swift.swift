import Shared

/// Swift-friendly (`Int64?`) wrappers over the SKIE-bridged `MotionSpec.Splash` (Kotlin nullable `Long` = `KotlinLong?`).
/// Distinct names on purpose: an `Int64?` overload with the Kotlin labels would make `exitStartMs: nil` ambiguous.
/// No timing logic here; it all lives in shared `MotionSpec`.
extension MotionSpec.Splash {
    func exitStart(readyAt: Int64?, elapsed: Int64) -> Int64? {
        exitStartMs(readyAtMs: readyAt.map(KotlinLong.init(value:)), elapsedMs: elapsed)?.int64Value
    }

    func frame(at elapsed: Int64, exitStart: Int64?, reduceMotion: Bool) -> SplashFrame {
        frameAt(elapsedMs: elapsed, exitStartMs: exitStart.map(KotlinLong.init(value:)), reduceMotion: reduceMotion)
    }
}
