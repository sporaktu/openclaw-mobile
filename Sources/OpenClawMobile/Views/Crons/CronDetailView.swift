import SwiftUI

struct CronDetailView: View {
    @Environment(CronService.self) private var cronService
    @Environment(\.dismiss) private var dismiss
    let job: CronJob
    @State private var showingDeleteConfirmation = false
    @State private var isRunning = false

    var body: some View {
        List {
            Section("Info") {
                LabeledContent("Name", value: job.effectiveName)
                LabeledContent("Schedule", value: job.humanSchedule)
                LabeledContent("Schedule Kind", value: job.scheduleKind)
                LabeledContent("Payload Kind", value: job.payloadKind)
                if let message = job.message {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Message")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(message)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                if let model = job.model {
                    LabeledContent("Model", value: model)
                }
            }

            Section("Status") {
                HStack {
                    Text("Enabled")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { job.enabled },
                        set: { newValue in
                            Task { try? await cronService.toggleJob(id: job.id, enabled: newValue) }
                        }
                    ))
                    .labelsHidden()
                }
                if let lastRun = job.lastRun {
                    LabeledContent("Last Run", value: lastRun)
                }
                if let status = job.lastStatus {
                    HStack {
                        Text("Last Status")
                        Spacer()
                        Text(status.capitalized)
                            .font(AppTheme.badgeFont)
                            .foregroundStyle(statusColor(for: status))
                    }
                }
                if let error = job.lastError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Error")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(error)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.statusBlocked)
                    }
                }
            }

            Section("History") {
                NavigationLink {
                    CronRunsView(cronId: job.id)
                } label: {
                    Label("Run History", systemImage: "list.bullet.clipboard")
                }
            }

            Section("Actions") {
                Button {
                    Task {
                        isRunning = true
                        try? await cronService.runJob(id: job.id)
                        isRunning = false
                    }
                } label: {
                    HStack {
                        Label("Run Now", systemImage: "play.fill")
                        if isRunning {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunning)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Job", systemImage: "trash")
                }
            }
        }
        .navigationTitle(job.effectiveName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete Cron Job", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await cronService.deleteJob(id: job.id)
                    dismiss()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "success": AppTheme.statusCompleted
        case "error": AppTheme.statusBlocked
        case "timeout": AppTheme.statusPending
        default: AppTheme.textTertiary
        }
    }
}

#Preview {
    NavigationStack {
        CronDetailView(job: CronJob(
            id: "1",
            name: "Daily Sync",
            label: nil,
            enabled: true,
            scheduleKind: "every",
            schedule: nil,
            everyMs: 3_600_000,
            at: nil,
            payloadKind: "agentTurn",
            message: "Run the daily sync process",
            model: "gpt-4",
            lastRun: "2025-03-20T10:00:00Z",
            lastStatus: "success",
            lastError: nil
        ))
        .environment(CronService())
    }
}
