import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = StatsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ReadingStreakView(
                        current: viewModel.currentStreak,
                        longest: viewModel.longestStreak
                    )

                    summaryCards

                    ActivityHeatmapView(dailyMinutes: viewModel.dailyMinutes)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    if !viewModel.recentSessions.isEmpty {
                        recentSessionsList
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Reading Stats")
        .onAppear { viewModel.load(modelContext: modelContext) }
    }

    private var summaryCards: some View {
        HStack(spacing: 16) {
            statCard(
                value: "\(viewModel.totalMinutes / 60)h \(viewModel.totalMinutes % 60)m",
                label: "Total Reading Time",
                icon: "clock.fill",
                color: .blue
            )
            statCard(
                value: "\(viewModel.booksReadThisYear)",
                label: "Books Started This Year",
                icon: "book.fill",
                color: .green
            )
            statCard(
                value: "\(viewModel.sessions.count)",
                label: "Total Sessions",
                icon: "list.bullet",
                color: .purple
            )
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
            ForEach(viewModel.recentSessions, id: \.id) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.bookTitle)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(session.startedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatDuration(session.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
