import SwiftUI

/// VoiceNoteIndicator (list rows): mic 14 + "0:42" (subhead 14/500, `textSecondary`) after a 1 x 14 `border` divider
/// in the due-line row; wraps to its own line when the row is narrow; never recolored by overdue.
/// Not interactive (the list can't play). The row label carries it: "..., voice note, 42 seconds".
struct VoiceNoteIndicator: View {
    let durationText: String

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.tk.border).frame(width: 1, height: 14)
            VoiceIcon(name: .mic, size: 14)
            Text(durationText).tkStyle(.subhead).monospacedDigit()
        }
        .foregroundStyle(Color.tk.textSecondary)
        .fixedSize()
        .accessibilityHidden(true)
    }
}
