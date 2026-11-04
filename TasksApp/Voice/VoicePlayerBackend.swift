import Foundation
import Shared

/// What a native player implements. `VoicePlayerAdapter` (Objective-C) exposes it to Kotlin as `AudioPlayer`.
/// Same semantics as the contract's `AudioPlayer`, with `prepare` split in two calls (it cannot be a Swift
/// witness of the Kotlin signature, see `VoicePlayerAdapter.h`).
@objc protocol VoicePlayerBackend: AnyObject {
    /// Loads the file; throws if unplayable. May be called again after `releasePlayer()`.
    @objc(prepareAtPath:error:) func prepare(atPath path: String) throws
    /// Duration in ms of the last prepared file.
    var durationMs: Int64 { get }
    func play()
    func pause()
    @objc(seekToMs:) func seek(toMs ms: Int64)
    /// 1.0 / 1.5 / 2.0. Must not start playback; may arrive before `prepare`.
    @objc(setRate:) func setRate(_ rate: Float)
    var positionMs: Int64 { get }
    var isPlaying: Bool { get }
    func releasePlayer()
    /// Set by shared; called when playback reaches the end (any thread).
    var onCompletion: (() -> Void)? { get set }
}

/// The Kotlin `AudioPlayer` for a Swift backend.
func makeAudioPlayer(_ backend: any VoicePlayerBackend) -> any AudioPlayer {
    VoicePlayerAdapter(backend: backend)
}
