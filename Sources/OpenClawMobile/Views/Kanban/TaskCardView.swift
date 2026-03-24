import SwiftUI

struct TaskCardView: View {
    let task: KanbanTask
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Priority + Labels
                HStack(spacing: 6) {
                    priorityBadge

                    ForEach(task.labels.prefix(2), id: \.self) { label in
                        Text(label)
                            .font(AppTheme.badgeFont)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.textTertiary.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                // Title
                Text(task.title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Footer
                HStack {
                    if let assignee = task.assignee {
                        Label(assignee.replacingOccurrences(of: "agent:", with: ""), systemImage: "person.circle")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    Spacer()

                    if let date = task.updatedDate {
                        Text(date, style: .relative)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
            .padding(AppTheme.cardPadding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .strokeBorder(priorityColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var priorityBadge: some View {
        Text(task.priority.label)
            .font(AppTheme.badgeFont)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priorityColor)
            .clipShape(Capsule())
    }

    private var priorityColor: Color {
        switch task.priority {
        case .critical: AppTheme.priorityCritical
        case .high: AppTheme.priorityHigh
        case .normal: AppTheme.priorityMedium
        case .low: AppTheme.priorityLow
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TaskCardView(task: KanbanTask(
            id: "1", title: "Implement user auth flow", description: "Add login/signup",
            status: .inProgress, priority: .high, createdBy: "operator",
            createdAt: Date().timeIntervalSince1970 * 1000,
            updatedAt: Date().timeIntervalSince1970 * 1000,
            version: 1, assignee: "agent:claude", labels: ["auth", "p0"], columnOrder: 0
        ))

        TaskCardView(task: KanbanTask(
            id: "2", title: "Fix memory leak in WebSocket handler",
            status: .review, priority: .critical, createdBy: "operator",
            createdAt: nil, updatedAt: nil,
            version: 1, labels: [], columnOrder: 1
        ))
    }
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
