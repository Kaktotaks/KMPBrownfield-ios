#if DEBUG
import Foundation
import Shared

// DEBUG-only deterministic voice audio, compiled out of Release. Lets the simulator (no microphone, no
// system permission dialog) show every voice-note state on demand. Enabled by launch arguments:
//
//   -FakeVoiceAudio                      fake recorder / player / permission + fake task data (the handoff sample
//                                        tasks, fixed "today" = 2 Nov 2026) on a freshly wiped database
//   -FakeMicPermission <state>           notDetermined | granted (default) | denied
//   -FakeMicRequestResult <result>       granted (default) | denied    what the system dialog "answers"
//   -FakeRecordFailure                   recorder.start throws        -> "Couldn't record. Try again."
//   -FakeVoiceUnavailable                seeded notes have no file    -> "Voice note unavailable"
//   -FakeVoiceSeed <spec>                tasks that start with a note: "1:65000,4:18000,5:42000" (default; id:ms)
//                                        or "none" (e.g. the empty Detail of task 5)
//
// Example: xcrun simctl launch booted <bundle id> -FakeVoiceAudio -FakeMicPermission notDetermined

struct DebugLaunch {
    static let current: DebugLaunch? = {
        ProcessInfo.processInfo.arguments.contains("-FakeVoiceAudio") ? DebugLaunch() : nil
    }()

    let micStatus: MicPermission
    let requestGranted: Bool
    let failRecording: Bool
    let unavailable: Bool
    let seed: [(taskId: Int32, durationMs: Int64)]
    let dateProvider: any DateProvider = PreviewDateProvider()

    private init() {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "FakeMicPermission") {
        case "notDetermined": micStatus = .notDetermined
        case "denied": micStatus = .denied
        default: micStatus = .granted
        }
        requestGranted = defaults.string(forKey: "FakeMicRequestResult") != "denied"
        let flags = ProcessInfo.processInfo.arguments
        failRecording = flags.contains("-FakeRecordFailure")
        unavailable = flags.contains("-FakeVoiceUnavailable")
        let spec = defaults.string(forKey: "FakeVoiceSeed") ?? "1:65000,4:18000,5:42000"
        seed = spec == "none" ? [] : spec.split(separator: ",").compactMap { pair in
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
            makePlayer: { makeAudioPlayer(FakeVoicePlayer(failPrepare: unavailable)) },
            permission: FakeMicPermission(status: micStatus, requestResult: requestGranted)
        )
    }

    /// Fake API (sample tasks) on a wiped database.
    @MainActor func makeRepository() -> TaskRepository {
        FakeStorage.wipe()
        return TasksIos.shared.createRepository(
            api: PreviewTaskApi(result: .success(AppDependencies.previewTasks)),
            dateProvider: dateProvider,
            logger: SharedLoggerCompanion.shared.NONE
        )
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

/// Test / preview isolation: `TasksIos.createRepository` opens the persistent `tasks.db`. Shared offers no in-memory
/// variant to Swift, so the database files (and stale voice files) are removed before a fresh repository is built.
enum FakeStorage {
    static func wipe() {
        let manager = FileManager.default
        let roots = [manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                     manager.urls(for: .documentDirectory, in: .userDomainMask).first,
                     manager.urls(for: .libraryDirectory, in: .userDomainMask).first].compactMap { $0 }
        for root in roots {
            for directory in [root, root.appendingPathComponent("databases")] {
                for suffix in ["", "-wal", "-shm", "-journal"] {
                    try? manager.removeItem(at: directory.appendingPathComponent("tasks.db" + suffix))
                }
            }
        }
        let voice = URL(fileURLWithPath: TasksIos.shared.voiceNotesDirectory())
        for file in (try? manager.contentsOfDirectory(at: voice, includingPropertiesForKeys: nil)) ?? [] {
            try? manager.removeItem(at: file)
        }
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
final class FakeVoicePlayer: NSObject, VoicePlayerBackend {
    var onCompletion: (() -> Void)?

    private let failPrepare: Bool
    private(set) var durationMs: Int64 = 0
    private var prepared = false
    private var speed: Float = 1
    private var basePositionMs: Int64 = 0
    private var playingSince: Date?
    private var generation = 0

    init(failPrepare: Bool) { self.failPrepare = failPrepare }

    func prepare(atPath path: String) throws {
        releasePlayer()
        if failPrepare { throw FakeVoiceError() }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8), let ms = Int64(text) else { throw FakeVoiceError() }
        durationMs = ms
        prepared = true
    }

    func play() {
        guard prepared, playingSince == nil else { return }
        playingSince = Date()
        scheduleCompletion()
    }

    func pause() {
        basePositionMs = positionMs
        playingSince = nil
        generation += 1
    }

    func seek(toMs ms: Int64) {
        basePositionMs = ms
        if playingSince != nil {
            playingSince = Date()
            scheduleCompletion()
        }
    }

    func setRate(_ rate: Float) {
        basePositionMs = positionMs
        if playingSince != nil { playingSince = Date() }
        speed = rate
        if playingSince != nil { scheduleCompletion() }
    }

    var positionMs: Int64 {
        guard let playingSince else { return basePositionMs }
        let advanced = Int64(Date().timeIntervalSince(playingSince) * 1000 * Double(speed))
        return min(basePositionMs + advanced, durationMs)
    }

    var isPlaying: Bool { playingSince != nil }

    func releasePlayer() {
        prepared = false
        playingSince = nil
        basePositionMs = 0
        generation += 1
    }

    private func scheduleCompletion() {
        generation += 1
        let token = generation
        let remaining = Double(durationMs - positionMs) / 1000 / Double(speed)
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
