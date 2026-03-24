import SwiftUI

struct CronRunsView: View {
    @Environment(CronService.self) private var cronService
    let cronId: String
    @State private var runs: [CronRun] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if runs.isEmpty {
                ContentUnavailableView(
                    "No Runs",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("This job hasn't run yet.")
                )
            } else {
                List(runs) { run in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(run.timestamp)
                                .font(AppTheme.bodyFont)
                            Spacer()
                            Text(run.status.capitalized)
                                .font(AppTheme.badgeFont)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(statusColor(for: run.statusColor).opacity(0.2))
                                .foregroundStyle(statusColor(for: run.statusColor))
                                .clipShape(Capsule())
                        }
                        if let duration = run.duration {
                            Text("\(duration)ms")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        if let summary = run.summary {
                            Text(summary)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        if let error = run.error {
                            Text(error)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.statusBlocked)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Run History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            runs = (try? await cronService.fetchRuns(id: cronId)) ?? []
            isLoading = false
        }
    }

    private func statusColor(for color: String) -> Color {
        switch color {
        case "green": AppTheme.statusCompleted
        case "red": AppTheme.statusBlocked
        case "yellow": AppTheme.statusPending
        default: AppTheme.textTertiary
        }
    }
}

#Preview {
    NavigationStack {
        CronRunsView(cronId: "1")
            .environment(CronService())
    }
}
