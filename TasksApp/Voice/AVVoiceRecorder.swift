import AVFoundation
import Shared

/// Native half of the shared `AudioRecorder`: AAC (MPEG-4 `.m4a`), mono, 44.1 kHz, 64 kbps, with metering.
/// Shared owns the files (it passes an absolute draft path and deletes/promotes the file); this class only records.
/// All calls come from the main thread (shared polls `level()` every 50 ms while recording).
final class AVVoiceRecorder: NSObject, AudioRecorder {
    private var recorder: AVAudioRecorder?

    func start(path: String) throws {
        cancel() // defensive: never two recordings at once
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
        do {
            let recorder = try AVAudioRecorder(url: URL(fileURLWithPath: path), settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else { throw AVVoiceError.cannotStart }
            self.recorder = recorder
        } catch {
            deactivateSession()
            throw error
        }
    }

    func level() -> Float {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        return VoiceLevel.normalized(decibels: recorder.averagePower(forChannel: 0))
    }

    func stop() throws {
        guard let recorder else { return }
        self.recorder = nil
        recorder.stop()
        deactivateSession()
    }

    /// Stops and leaves the file for shared to delete. Never throws, safe when idle.
    func cancel() {
        guard let recorder else { return }
        self.recorder = nil
        recorder.stop()
        deactivateSession()
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum AVVoiceError: Error {
    case cannotStart
}
