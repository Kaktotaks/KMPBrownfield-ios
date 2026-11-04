import Foundation

/// Input-level mapping of the recorder adapter (API_CONTRACT §4: `level()` is 0..1).
enum VoiceLevel {
    /// Quietest level that still shows movement; everything below is 0 (silence reports about -160 dB).
    static let floorDecibels: Float = -50

    /// `AVAudioRecorder.averagePower(forChannel:)` (dBFS, <= 0) mapped from -50...0 dB to 0...1.
    /// Android: `sqrt(maxAmplitude / 32767)`; the two curves are compared visually in the handoff.
    static func normalized(decibels: Float) -> Float {
        guard decibels.isFinite else { return 0 }
        return min(max((decibels - floorDecibels) / -floorDecibels, 0), 1)
    }
}
