import SwiftUI

/// Error state: "Couldn't load tasks." + "Retry".
struct LoadErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Couldn't load tasks.")
                .foregroundStyle(Color.secondary)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading state: spinner.
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
