import AVFoundation
import Shared

/// Native half of the shared `AudioPlayer` (reached through `VoicePlayerAdapter`): `AVAudioPlayer` with rate control (1x / 1.5x / 2x).
/// Shared calls `prepare` lazily and `release()` whenever the note changes or a recording starts,
/// so no native player is held across notes. All calls come from the main thread.
final class AVVoicePlayer: NSObject, VoicePlayerBackend, AVAudioPlayerDelegate {
    var onCompletion: (() -> Void)?

    private var player: AVAudioPlayer?
    private(set) var durationMs: Int64 = 0
    /// `setRate` may arrive before `prepare` (shared sets it on a note change): applied on prepare.
    private var speed: Float = 1

    func prepare(atPath path: String) throws {
        releasePlayer()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        player.enableRate = true
        player.delegate = self
        player.rate = speed
        guard player.prepareToPlay() else { throw AVVoiceError.cannotStart }
        self.player = player
        durationMs = Int64((player.duration * 1000).rounded())
    }

    func play() {
        guard let player else { return }
        player.rate = speed
        player.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(toMs ms: Int64) {
        player?.currentTime = Double(ms) / 1000
    }

    /// Does not start playback: `rate` only changes how fast a running player goes.
    func setRate(_ rate: Float) {
        speed = rate
        player?.rate = rate
    }

    var positionMs: Int64 {
        Int64(((player?.currentTime ?? 0) * 1000).rounded())
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func releasePlayer() {
        guard let player else { return }
        self.player = nil
        player.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: AVAudioPlayerDelegate (called on the main thread)

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onCompletion?()
    }
}
