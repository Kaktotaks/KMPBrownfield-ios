import SwiftUI
import Shared

@MainActor
struct StatsScreen: View {
    /// Kotlin `StatsViewModel` (StatsCalculator over repository.state) behind the Swift wrapper.
    @State private var model: StatsModel

    init(app: AppDependencies) {
        _model = State(initialValue: app.makeStats())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stats")
        }
    }

    @ViewBuilder
    private var content: some View {
        // SKIE: Kotlin sealed `StatsUiState` → exhaustive Swift enum.
        switch onEnum(of: model.state) {
        case .loading:
            LoadingView()
        case .error:
            LoadErrorView {
                model.send { $0.onRetry() }
            }
        case .loaded(let loaded):
            statsList(loaded.stats)
        }
    }

    private func statsList(_ stats: TaskStats) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Text("\(stats.completionPercent)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    ProgressView(value: Double(stats.completionPercent), total: 100)
                }
                .padding(.vertical, 4)
            }

            Section {
                row("Total", stats.total)
                row("Done", stats.done)
                row("Active", stats.active)
                row("Overdue", stats.overdue)
            }

            Section("By priority") {
                row("High", stats.high)
                row("Medium", stats.medium)
                row("Low", stats.low)
            }
        }
    }

    private func row(_ title: String, _ value: Int32) -> some View {
        LabeledContent(title, value: "\(value)")
    }
}
