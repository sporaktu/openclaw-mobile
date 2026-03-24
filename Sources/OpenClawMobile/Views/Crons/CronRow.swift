import SwiftUI

struct CronRow: View {
    let job: CronJob

    var body: some View {
        HStack(spacing: AppTheme.spacing) {
            statusDot
            VStack(alignment: .leading, spacing: 4) {
                Text(job.effectiveName)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(job.humanSchedule)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                if let date = job.lastRunDate {
                    Text(date, style: .relative)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            Spacer()
            Circle()
                .fill(job.enabled ? AppTheme.statusCompleted : AppTheme.textTertiary)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusDot: some View {
        let color: Color = switch job.lastStatus {
        case "success": AppTheme.statusCompleted
        case "error": AppTheme.statusBlocked
        case "timeout": AppTheme.statusPending
        default: AppTheme.textTertiary
        }
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}

#Preview {
    List {
        CronRow(job: CronJob(
            id: "1",
            name: "Daily Sync",
            label: nil,
            enabled: true,
            scheduleKind: "every",
            schedule: nil,
            everyMs: 3_600_000,
            at: nil,
            payloadKind: "agentTurn",
            message: "Run sync",
            model: nil,
            lastRun: nil,
            lastStatus: "success",
            lastError: nil
        ))
        CronRow(job: CronJob(
            id: "2",
            name: nil,
            label: "Backup",
            enabled: false,
            scheduleKind: "cron",
            schedule: "0 * * * *",
            everyMs: nil,
            at: nil,
            payloadKind: "systemEvent",
            message: "backup",
            model: nil,
            lastRun: nil,
            lastStatus: "error",
            lastError: "timeout"
        ))
    }
}
