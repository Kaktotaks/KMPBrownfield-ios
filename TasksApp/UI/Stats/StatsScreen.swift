import SwiftUI
import Shared

/// Stats tab. UI only: display-ready stats come from `StatsViewModel`.
@MainActor
struct StatsScreen: View {
    @State var model: StatsViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.content {
                case .loading:
                    LoadingView()
                case .error:
                    LoadErrorView { model.retry() }
                case .loaded(let summary):
                    StatsSummaryList(summary: summary)
                }
            }
            .navigationTitle("Stats")
        }
    }
}

/// Completion percentage + counters.
struct StatsSummaryList: View {
    let summary: StatsSummary

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Text(summary.completionText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    ProgressView(value: summary.completionValue, total: 100)
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(summary.totals) { row in
                    LabeledContent(row.title, value: row.value)
                }
            }

            Section("By priority") {
                ForEach(summary.byPriority) { row in
                    LabeledContent(row.title, value: row.value)
                }
            }
        }
    }
}
