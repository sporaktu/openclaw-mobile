import SwiftUI
import WidgetKit

// MARK: - Active Tasks Widget (Medium)

struct ActiveTasksWidget: Widget {
    let kind = "ActiveTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActiveTasksTimelineProvider()) { entry in
            ActiveTasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Active Tasks")
        .description("Shows task counts and in-progress work.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline

struct ActiveTasksEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct ActiveTasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveTasksEntry {
        ActiveTasksEntry(date: .now, data: WidgetData())
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveTasksEntry) -> Void) {
        let data = WidgetDataStore.load()
        completion(ActiveTasksEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveTasksEntry>) -> Void) {
        let data = WidgetDataStore.load()
        let entry = ActiveTasksEntry(date: .now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - View

struct ActiveTasksWidgetView: View {
    let entry: ActiveTasksEntry

    private var counts: [String: Int] { entry.data.taskCountByStatus }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status badges
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text("Tasks")
                    .font(.caption.bold())

                Spacer()

                statusBadge("todo", color: .blue)
                statusBadge("in-progress", color: .orange)
                statusBadge("review", color: .yellow)
                statusBadge("done", color: .green)
            }

            Divider()

            // In-progress tasks
            if entry.data.topInProgressTasks.isEmpty {
                Text("No tasks in progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.data.topInProgressTasks) { task in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(priorityColor(task.priority))
                                .frame(width: 6, height: 6)

                            Text(task.title)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "openclaw://kanban"))
    }

    private func statusBadge(_ status: String, color: Color) -> some View {
        let count = counts[status] ?? 0
        return Text("\(count)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(count > 0 ? color : color.opacity(0.3))
            .clipShape(Capsule())
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "critical": .red
        case "high": .orange
        case "normal": .yellow
        case "low": .green
        default: .gray
        }
    }
}

#Preview(as: .systemMedium) {
    ActiveTasksWidget()
} timeline: {
    ActiveTasksEntry(date: .now, data: WidgetData(
        taskCountByStatus: ["backlog": 5, "todo": 3, "in-progress": 2, "review": 1, "done": 8],
        topInProgressTasks: [
            WidgetTaskInfo(id: "1", title: "Implement auth flow", priority: "high"),
            WidgetTaskInfo(id: "2", title: "Fix memory leak in WS handler", priority: "critical"),
        ],
        totalTaskCount: 19
    ))
}
