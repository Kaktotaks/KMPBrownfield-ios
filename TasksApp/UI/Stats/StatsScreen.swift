import SwiftUI

@MainActor
struct StatsScreen: View {
    @State private var viewModel: StatsViewModel

    init(repository: TaskRepository, clock: any Clock) {
        _viewModel = State(initialValue: StatsViewModel(repository: repository, clock: clock))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stats")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            LoadingView()
        case .error:
            LoadErrorView {
                viewModel.retry()
            }
        case .loaded:
            statsList(viewModel.stats)
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

    private func row(_ title: String, _ value: Int) -> some View {
        LabeledContent(title, value: "\(value)")
    }
}
