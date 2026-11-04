import SwiftUI

/// VoiceRecorder (notes board): red dot + "Recording" + hint on the right, timer (Inter Tight 800 48/52),
/// live waveform (56 high), then Cancel (surface2, 1 fr) + Stop (accent, 2 fr), both 52 high.
/// The dot pulses 1 <-> 0.3 per 1000 ms half-cycle (Reduce Motion: solid). The last 10 s switch hint and timer to `danger`.
struct VoiceRecorderView: View {
    let recording: VoiceNoteCardModel.Recording
    let onCancel: () -> Void
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                dot
                Text("voice_recording")
                    .tkStyle(.headline)
                    .foregroundStyle(Color.tk.textPrimary)
                Spacer(minLength: 8)
                Text(recording.hintText)
                    .tkStyle(recording.isWarning ? .subheadStrong : .subhead)
                    .foregroundStyle(recording.isWarning ? Color.tk.danger : Color.tk.textSecondary)
                    .monospacedDigit()
            }
            // One label for the whole header: the running timer is not read every second (it announces instead).
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("voice_recording"))

            Text(recording.timerText)
                .tkStyle(.recorderTimer)
                .foregroundStyle(recording.isWarning ? Color.tk.danger : Color.tk.textPrimary)
                .padding(.top, 6)
                .tkAnimation(Motion.emphasized(Motion.short), value: recording.isWarning)
                .accessibilityHidden(true)

            WaveformView(levels: recording.levels, mode: .live, height: 56)
                .padding(.top, 10)

            WeightedRow(weights: [1, 2], spacing: 10) {
                VoiceButton(title: "voice_cancel", style: .neutral, icon: { TKIcon(name: .close, size: 18) }, action: onCancel)
                VoiceButton(title: "voice_stop", style: .accent, icon: { VoiceIcon(name: .stop, size: 18) }, action: onStop)
            }
            .padding(.top, 14)
        }
    }

    private var dot: some View {
        ZStack {
            Circle().fill(Color.tk.dangerContainer).frame(width: 22, height: 22)
            Circle()
                .fill(Color.tk.danger)
                .frame(width: 10, height: 10)
                .opacity(reduceMotion ? 1 : (dimmed ? 0.3 : 1))
        }
        .onAppear {
            guard !reduceMotion else { return }
            // 1 -> 0.3 and back: 1000 ms is one half-cycle (parity with Android).
            withAnimation(.easeInOut(duration: Double(Motion.recordingDotCycle) / 1000).repeatForever(autoreverses: true)) {
                dimmed = true
            }
        }
        .accessibilityHidden(true)
    }
}
