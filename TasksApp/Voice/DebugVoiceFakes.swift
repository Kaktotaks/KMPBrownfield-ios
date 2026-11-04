#if DEBUG
import Foundation
import Shared

// DEBUG-only deterministic voice audio, compiled out of Release. Lets the simulator (no microphone, no
// system permission dialog) show every voice-note state on demand. Same names and meaning as the Android debug
// intent extras; pass them as launch arguments (`-name value`, flags without a value):
//
//   -fakeVoiceAudio                      fake recorder (moving levels) / player (wall clock) / permission, plus fake
//                                        task data (the handoff sample tasks, "today" = 2 Nov 2026) in an in-memory database
//   -fakeMicPermission <state>           notDetermined | granted (default) | denied
//   -fakeMicDenyOnRequest                the system dialog answers "Don't Allow" -> "Microphone access is off"
//   -forceVoiceError <kind>              recordFailed: start throws -> "Couldn't record. Try again."
//                                        unavailable: seeded notes cannot be played -> "Voice note unavailable"
//   -seedVoice "taskId:durationMs,..."   attaches a fake voice note (40 synthetic bars) to those tasks after the load
//
// Example: xcrun simctl launch booted com.example.tasks.ios -fakeVoiceAudio -fakeMicPermission notDetermined -seedVoice "5:42000"

struct DebugLaunch {
    static let current: DebugLaunch? = {
        ProcessInfo.processInfo.arguments.contains("-fakeVoiceAudio") ? DebugLaunch() : nil
    }()

    let micStatus: MicPermission
    let requestGranted: Bool
    let failRecording: Bool
    let unavailable: Bool
    let seed: [(taskId: Int32, durationMs: Int64)]
    let dateProvider: any DateProvider = PreviewDateProvider()

    private init() {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "fakeMicPermission") {
        case "notDetermined": micStatus = .notDetermined
        case "denied": micStatus = .denied
        default: micStatus = .granted
        }
        requestGranted = !ProcessInfo.processInfo.arguments.contains("-fakeMicDenyOnRequest")
        let forced = defaults.string(forKey: "forceVoiceError")
        failRecording = forced == "recordFailed"
        unavailable = forced == "unavailable"
        let spec = defaults.string(forKey: "seedVoice") ?? ""
        seed = spec.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: ":")
            guard parts.count == 2, let id = Int32(parts[0]), let ms = Int64(parts[1]) else { return nil }
            return (id, ms)
        }
    }

    var audio: VoiceAudio {
        let failRecording = failRecording
        let unavailable = unavailable
        return VoiceAudio(
            makeRecorder: { FakeVoiceRecorder(failStart: failRecording) },
            makePlayer: { FakeVoicePlayer(failPrepare: unavailable) },
            permission: FakeMicPermission(status: micStatus, requestResult: requestGranted)
        )
    }

    /// Fake API (sample tasks) in an in-memory database.
    @MainActor func makeRepository() -> TaskRepository {
        FakeStorage.makeRepository(api: PreviewTaskApi(result: .success(AppDependencies.previewTasks)), dateProvider: dateProvider)
    }

    /// Gives the configured tasks a voice note whose "audio file" is a text file holding the duration.
    func seedIfNeeded(_ repository: TaskRepository) {
        for (taskId, durationMs) in seed {
            guard let task = repository.task(id: taskId), task.voiceNote == nil else { continue }
            let name = "note-seed-\(taskId).m4a"
            if !unavailable {
                try? "\(durationMs)".write(toFile: repository.voiceFiles.pathOf(name: name), atomically: true, encoding: .utf8)
            }
            repository.setVoiceNote(taskId: taskId, note: VoiceNote(
                fileName: name,
                durationMs: durationMs,
                waveform: FakeVoiceRecorder.sampleWaveform.map { KotlinFloat(float: $0) }
            ))
        }
    }
}

extension VoiceAudio {
    /// Fake adapters for previews and tests.
    static func fake(
        permission: MicPermission = .granted,
        requestGranted: Bool = true,
        failRecording: Bool = false,
        unavailable: Bool = false
    ) -> VoiceAudio {
        VoiceAudio(
            makeRecorder: { FakeVoiceRecorder(failStart: failRecording) },
            makePlayer: { FakeVoicePlayer(failPrepare: unavailable) },
            permission: FakeMicPermission(status: permission, requestResult: requestGranted)
        )
    }
}

/// Test / preview isolation: a repository over an in-memory SQLite database (nothing touches `tasks.db`) with its own
/// temporary voice directory, so every call starts "never seeded" and leaves no files in Application Support.
enum FakeStorage {
    @MainActor
    static func makeRepository(api: any TaskApi, dateProvider: any DateProvider) -> TaskRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return TasksIos.shared.createInMemoryRepository(
            api: api,
            dateProvider: dateProvider,
            voiceDirectory: directory.path,
            logger: SharedLoggerCompanion.shared.NONE
        )
    }
}

private struct FakeVoiceError: Error {}

/// Records nothing: writes the elapsed milliseconds into the draft file on stop so the fake player can "play" it.
final class FakeVoiceRecorder: NSObject, AudioRecorder {
    static let sampleWaveform: [Float] = (0..<40).map { i in
        let x = Float(i)
        return min(1, max(0.08, 0.45 + 0.4 * sin(x * 0.9) * cos(x * 0.31)))
    }

    private let failStart: Bool
    private var path: String?
    private var startedAt: Date?

    init(failStart: Bool) { self.failStart = failStart }

    func start(path: String) throws {
        if failStart { throw FakeVoiceError() }
        try "0".write(toFile: path, atomically: true, encoding: .utf8)
        self.path = path
        startedAt = Date()
    }

    /// Deterministic "speech": a slow envelope times a faster wobble, moving with the clock.
    func level() -> Float {
        guard let startedAt else { return 0 }
        let t = Float(Date().timeIntervalSince(startedAt))
        return min(1, max(0.05, 0.1 + 0.8 * abs(sin(t * 2.3)) * (0.55 + 0.45 * abs(sin(t * 9.1)))))
    }

    func stop() throws {
        if let path, let startedAt {
            try "\(Int(Date().timeIntervalSince(startedAt) * 1000))".write(toFile: path, atomically: true, encoding: .utf8)
        }
        path = nil
        startedAt = nil
    }

    func cancel() {
        path = nil
        startedAt = nil
    }
}

/// "Plays" a note on the wall clock (rate-aware); the duration is read from the fake audio file.
final class FakeVoicePlayer: NSObject, AudioPlayer {
    var onCompletion: (() -> Void)?

    private let failPrepare: Bool
    private var duration: Int64 = 0
    private var prepared = false
    private var speed: Float = 1
    private var basePositionMs: Int64 = 0
    private var playingSince: Date?
    private var generation = 0

    init(failPrepare: Bool) { self.failPrepare = failPrepare }

    func prepare(path: String) throws {
        dispose()
        if failPrepare { throw FakeVoiceError() }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8), let ms = Int64(text) else { throw FakeVoiceError() }
        duration = ms
        prepared = true
    }

    func durationMs() -> Int64 { duration }

    func play() {
        guard prepared, playingSince == nil else { return }
        playingSince = Date()
        scheduleCompletion()
    }

    func pause() {
        basePositionMs = positionMs()
        playingSince = nil
        generation += 1
    }

    func seekTo(positionMs: Int64) {
        basePositionMs = positionMs
        if playingSince != nil {
            playingSince = Date()
            scheduleCompletion()
        }
    }

    func setSpeed(speed: Float) {
        basePositionMs = positionMs()
        if playingSince != nil { playingSince = Date() }
        self.speed = speed
        if playingSince != nil { scheduleCompletion() }
    }

    func positionMs() -> Int64 {
        guard let playingSince else { return basePositionMs }
        let advanced = Int64(Date().timeIntervalSince(playingSince) * 1000 * Double(speed))
        return min(basePositionMs + advanced, duration)
    }

    func isPlaying() -> Bool { playingSince != nil }

    func dispose() {
        prepared = false
        playingSince = nil
        basePositionMs = 0
        generation += 1
    }

    private func scheduleCompletion() {
        generation += 1
        let token = generation
        let remaining = Double(duration - positionMs()) / 1000 / Double(speed)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(remaining, 0)) { [weak self] in
            guard let self, token == generation, playingSince != nil else { return }
            playingSince = nil
            basePositionMs = 0
            onCompletion?()
        }
    }
}

/// A permission that answers the request instantly with a fixed result (no system dialog).
final class FakeMicPermission: NSObject, MicPermissionProvider {
    private var current: MicPermission
    private let requestResult: Bool

    init(status: MicPermission, requestResult: Bool) {
        current = status
        self.requestResult = requestResult
    }

    func status() -> MicPermission { current }

    func request(onResult: @escaping (KotlinBoolean) -> Void) {
        let granted = requestResult
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            current = granted ? .granted : .denied
            onResult(KotlinBoolean(bool: granted))
        }
    }
}
#endif
