import XCTest
import Shared
@testable import TasksApp

/// Voice notes on iOS: the Swift side only maps and adapts. The state machine itself is tested once, in shared/src/commonTest.
final class VoiceNoteCardModelTests: XCTestCase {
    private func note(durationMs: Int64 = 42_000) -> VoiceNote {
        VoiceNote(fileName: "note-1.m4a", durationMs: durationMs, waveform: (0..<40).map { KotlinFloat(float: Float($0) / 40) })
    }

    func testEmptyPermissionAndDeniedMapOneToOne() {
        XCTAssertEqual(VoiceNoteCardModel(state: VoiceNoteUiState.Empty.shared), .empty)
        XCTAssertEqual(VoiceNoteCardModel(state: VoiceNoteUiState.PermissionExplainer.shared), .permissionAsk)
        XCTAssertEqual(VoiceNoteCardModel(state: VoiceNoteUiState.PermissionDenied.shared), .permissionDenied)
    }

    func testRecordingShowsTimerAndMaxHint() {
        let levels = (0..<32).map { KotlinFloat(float: Float($0) / 32) }
        let state = VoiceNoteUiState.Recording(elapsedMs: 7_400, remainingMs: 112_600, isWarning: false, levels: levels)
        guard case .recording(let recording) = VoiceNoteCardModel(state: state) else { return XCTFail("expected recording") }
        XCTAssertEqual(recording.timerText, "0:07")
        XCTAssertEqual(recording.hintText, "max 2:00")
        XCTAssertFalse(recording.isWarning)
        XCTAssertEqual(recording.levels.count, 32)
        XCTAssertEqual(recording.levels[16], 0.5, accuracy: 0.001)
    }

    func testLastTenSecondsSwitchesHintToRemainingTime() {
        let levels = [KotlinFloat](repeating: KotlinFloat(float: 0), count: 32)
        let state = VoiceNoteUiState.Recording(elapsedMs: 111_000, remainingMs: 9_000, isWarning: true, levels: levels)
        guard case .recording(let recording) = VoiceNoteCardModel(state: state) else { return XCTFail("expected recording") }
        XCTAssertEqual(recording.timerText, "1:51")
        XCTAssertEqual(recording.hintText, "0:09 left")
        XCTAssertTrue(recording.isWarning)
    }

    func testSecondsLeftRoundsUp() {
        let levels = [KotlinFloat](repeating: KotlinFloat(float: 0), count: 32)
        let state = VoiceNoteUiState.Recording(elapsedMs: 111_100, remainingMs: 8_900, isWarning: true, levels: levels)
        guard case .recording(let recording) = VoiceNoteCardModel(state: state) else { return XCTFail("expected recording") }
        XCTAssertEqual(recording.hintText, "0:09 left")
    }

    func testReadyMapsPlayerTexts() {
        let state = VoiceNoteUiState.Ready(note: note(), positionMs: 12_900, isPlaying: true, speed: 1.5, progress: 0.3)
        guard case .player(let player) = VoiceNoteCardModel(state: state) else { return XCTFail("expected player") }
        XCTAssertEqual(player.positionText, "0:12")
        XCTAssertEqual(player.durationText, "0:42")
        XCTAssertEqual(player.speedText, "1.5×")
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.progress, 0.3, accuracy: 0.0001)
        XCTAssertEqual(player.waveform.count, 40)
        XCTAssertEqual(player.accessibilityLabel, "Voice note, 42 seconds")
        XCTAssertEqual(player.accessibilityValue, "0:12 of 0:42")
    }

    func testErrorKindsMapToTheTwoErrorCards() {
        XCTAssertEqual(VoiceNoteCardModel(state: VoiceNoteUiState.Error(kind: .recordFailed)), .recordFailed)
        XCTAssertEqual(VoiceNoteCardModel(state: VoiceNoteUiState.Error(kind: .unavailable)), .unavailable)
    }

    func testSpeedText() {
        XCTAssertEqual(VoiceNoteCardModel.speedText(1), "1×")
        XCTAssertEqual(VoiceNoteCardModel.speedText(1.5), "1.5×")
        XCTAssertEqual(VoiceNoteCardModel.speedText(2), "2×")
    }

    func testSpokenDurations() {
        XCTAssertEqual(VoiceSpeech.duration(ms: 42_900), "42 seconds")
        XCTAssertEqual(VoiceSpeech.duration(ms: 1_000), "1 second")
        XCTAssertEqual(VoiceSpeech.duration(ms: 65_000), "1 minute 5 seconds")
        XCTAssertEqual(VoiceSpeech.duration(ms: 120_000), "2 minutes")
    }

    func testListRowCarriesTheIndicatorOnlyWithANote() {
        let today = LocalDate(year: 2026, month: 11, day: 2)
        let due = LocalDate(year: 2026, month: 11, day: 5)
        let plain = TaskItem(id: 1, title: "A", notes: "", priority: .low, dueDate: due, isDone: false)
        let withNote = TaskItem(id: 2, title: "B", notes: "", priority: .low, dueDate: due, isDone: false, voiceNote: note())
        XCTAssertNil(TaskRowItem(task: plain, today: today).voice)
        XCTAssertEqual(TaskRowItem(task: withNote, today: today).voice, VoiceRowInfo(durationText: "0:42", durationMs: 42_000))
    }
}

final class VoiceLevelTests: XCTestCase {
    func testDecibelsMapMinus50To0Onto0To1() {
        XCTAssertEqual(VoiceLevel.normalized(decibels: -50), 0, accuracy: 0.0001)
        XCTAssertEqual(VoiceLevel.normalized(decibels: -25), 0.5, accuracy: 0.0001)
        XCTAssertEqual(VoiceLevel.normalized(decibels: 0), 1, accuracy: 0.0001)
    }

    func testOutOfRangeAndSilenceAreClamped() {
        XCTAssertEqual(VoiceLevel.normalized(decibels: -160), 0) // AVAudioRecorder silence
        XCTAssertEqual(VoiceLevel.normalized(decibels: -.infinity), 0)
        XCTAssertEqual(VoiceLevel.normalized(decibels: 6), 1)
    }
}

// MARK: - Swift adapters driving the Kotlin ViewModel

/// A Swift implementation of the Kotlin `AudioRecorder` (a plain, non-suspend interface: no `__` renaming).
private final class SpyRecorder: NSObject, AudioRecorder {
    var startedPaths: [String] = []
    var stopCount = 0
    var cancelCount = 0
    var nextLevel: Float = 0.5

    func start(path: String) throws {
        startedPaths.append(path)
        try Data("fake-aac".utf8).write(to: URL(fileURLWithPath: path)) // shared promotes this file on stop
    }

    func level() -> Float { nextLevel }
    func stop() throws { stopCount += 1 }
    func cancel() { cancelCount += 1 }
}

/// `MonotonicClock` under test control: the ViewModel's timer reads this, not the wall clock.
private final class FixedClock: NSObject, MonotonicClock {
    var now: Int64 = 0
    func nowMs() -> Int64 { now }
}

@MainActor
final class VoiceNoteInteropTests: XCTestCase {
    func testSwiftRecorderFakeDrivesKotlinViewModelStartTickStop() async throws {
        let repository = makeTestRepository(api: FakeTaskApi(result: .success([])), dateProvider: SystemDateProvider.shared)
        try await repository.load()
        let recorder = SpyRecorder()
        let clock = FixedClock()
        let vm = Shared.VoiceNoteViewModel(
            target: VoiceNoteTarget.Draft(initial: nil),
            repository: repository,
            files: repository.voiceFiles,
            recorder: recorder,
            player: FakeVoicePlayer(failPrepare: false),
            permission: FakeMicPermission(status: .granted, requestResult: true),
            clock: clock
        )
        defer { vm.clear() }
        XCTAssertEqual(VoiceNoteCardModel(state: vm.uiState.value), .empty)

        // Start: permission granted -> recording into a draft file shared chose.
        vm.onRecordTapped()
        XCTAssertEqual(recorder.startedPaths.count, 1)
        XCTAssertTrue(recorder.startedPaths[0].contains("draft-"))
        XCTAssertTrue(recorder.startedPaths[0].hasSuffix(".m4a"))

        // Tick: the clock moves 3 s, the next 50 ms tick publishes it together with the polled level.
        clock.now = 3_000
        await waitUntil { if case .recording(let r) = VoiceNoteCardModel(state: vm.uiState.value) { return r.elapsedMs == 3_000 } else { return false } }
        guard case .recording(let recording) = VoiceNoteCardModel(state: vm.uiState.value) else { return XCTFail("expected recording") }
        XCTAssertEqual(recording.elapsedMs, 3_000)
        XCTAssertEqual(recording.timerText, "0:03")
        XCTAssertEqual(recording.levels.count, 32)
        XCTAssertEqual(recording.levels.last ?? -1, 0.5, accuracy: 0.0001)

        // Stop: duration is the elapsed time rounded to 100 ms, the draft became the note, the recorder was stopped once.
        vm.onStop()
        XCTAssertEqual(recorder.stopCount, 1)
        guard case .player(let player) = VoiceNoteCardModel(state: vm.uiState.value) else { return XCTFail("expected player") }
        XCTAssertEqual(player.durationMs, 3_000)
        XCTAssertEqual(player.durationText, "0:03")
        XCTAssertEqual(player.waveform.count, 40)
        XCTAssertTrue(repository.voiceFiles.exists(name: player.fileName))
        XCTAssertEqual(vm.currentNote()?.fileName, player.fileName)
    }

    func testDeniedPermissionNeverStartsTheRecorder() {
        let repository = makeTestRepository(api: FakeTaskApi(result: .success([])), dateProvider: SystemDateProvider.shared)
        let recorder = SpyRecorder()
        let vm = Shared.VoiceNoteViewModel(
            target: VoiceNoteTarget.Draft(initial: nil),
            repository: repository,
            files: repository.voiceFiles,
            recorder: recorder,
            player: FakeVoicePlayer(failPrepare: false),
            permission: FakeMicPermission(status: .denied, requestResult: false)
        )
        defer { vm.clear() }
        vm.onRecordTapped()
        XCTAssertEqual(VoiceNoteCardModel(state: vm.uiState.value), .permissionDenied)
        XCTAssertTrue(recorder.startedPaths.isEmpty)
    }
}
