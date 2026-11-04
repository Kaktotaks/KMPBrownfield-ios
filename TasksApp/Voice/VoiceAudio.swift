import Shared

/// The three native adapters of a voice-note card. The recorder and the player are created per
/// ViewModel (each shared `VoiceNoteViewModel` sets `onCompletion` on its own player and releases it on
/// clear, so one instance shared by Detail and the Editor sheet would lose the other's callback); they hold no native
/// resources until used. Permission is stateless and shared.
struct VoiceAudio {
    let makeRecorder: () -> any AudioRecorder
    let makePlayer: () -> any AudioPlayer
    let permission: any MicPermissionProvider

    static let live = VoiceAudio(
        makeRecorder: { AVVoiceRecorder() },
        makePlayer: { AVVoicePlayer() },
        permission: AVMicPermission()
    )
}
