import AVFoundation
import Shared

/// Native half of the shared `MicPermissionProvider` (`AVAudioApplication`, iOS 17+).
final class AVMicPermission: NSObject, MicPermissionProvider {
    func status() -> MicPermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    /// The system calls back on an arbitrary queue: hop to the main actor for shared.
    func request(onResult: @escaping (KotlinBoolean) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in onResult(KotlinBoolean(bool: granted)) }
        }
    }
}
