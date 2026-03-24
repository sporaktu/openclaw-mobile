import SwiftUI

struct KanbanColumnView: View {
    let status: TaskStatus
    let tasks: [KanbanTask]
    var onTaskTap: ((KanbanTask) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Image(systemName: status.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(columnColor)

                Text(status.label)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)

                Text("\(tasks.count)")
                    .font(AppTheme.badgeFont)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.textTertiary.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground.opacity(0.5))

            // Cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCardView(task: task) {
                            onTaskTap?(task)
                        }
                        .contextMenu {
                            ForEach(TaskStatus.boardColumns.filter { $0 != status }, id: \.rawValue) { targetStatus in
                                Button {
                                    onTaskTap?(task) // For now, open detail to move
                                } label: {
                                    Label("Move to \(targetStatus.label)", systemImage: targetStatus.icon)
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.textTertiary.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var columnColor: Color {
        switch status {
        case .backlog: AppTheme.textTertiary
        case .todo: AppTheme.accent
        case .inProgress: AppTheme.statusInProgress
        case .review: AppTheme.statusPending
        case .done: AppTheme.statusCompleted
        case .cancelled: AppTheme.statusBlocked
        }
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            KanbanColumnView(status: .todo, tasks: [
                KanbanTask(id: "1", title: "Task A", status: .todo, priority: .high,
                           version: 1, labels: ["ui"], columnOrder: 0),
                KanbanTask(id: "2", title: "Task B", status: .todo, priority: .normal,
                           version: 1, labels: [], columnOrder: 1),
            ])

            KanbanColumnView(status: .inProgress, tasks: [
                KanbanTask(id: "3", title: "Working on C", status: .inProgress, priority: .critical,
                           version: 1, assignee: "agent:claude", labels: [], columnOrder: 0),
            ])
        }
        .padding()
    }
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
