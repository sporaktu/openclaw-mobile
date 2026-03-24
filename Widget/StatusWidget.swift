import SwiftUI
import WidgetKit

// MARK: - Status Widget (Small + Medium)

struct StatusWidget: Widget {
    let kind = "StatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusTimelineProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Agent Status")
        .description("Shows your OpenClaw agent's connection status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct StatusEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Timeline Provider

struct StatusTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, data: WidgetData())
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        let data = WidgetDataStore.load()
        completion(StatusEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let data = WidgetDataStore.load()
        let entry = StatusEntry(date: .now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.data.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)

                Text(entry.data.isConnected ? "Connected" : "Offline")
                    .font(.caption.bold())
                    .foregroundStyle(entry.data.isConnected ? .green : .red)
            }

            Spacer()

            Text(entry.data.agentName.isEmpty ? "Agent" : entry.data.agentName)
                .font(.headline)
                .lineLimit(2)

            if let lastActivity = entry.data.lastActivityTime {
                Text(lastActivity, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "openclaw://dashboard"))
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: status info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.data.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)

                    Text(entry.data.isConnected ? "Connected" : "Offline")
                        .font(.caption.bold())
                }

                Text(entry.data.agentName.isEmpty ? "Agent" : entry.data.agentName)
                    .font(.headline)
                    .lineLimit(1)

                if !entry.data.modelName.isEmpty {
                    Text(entry.data.modelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let lastActivity = entry.data.lastActivityTime {
                    Text(lastActivity, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Right: stats
            VStack(alignment: .leading, spacing: 8) {
                statRow(icon: "rectangle.stack", label: "Sessions", value: "\(entry.data.activeSessionCount)")
                statRow(icon: "checklist", label: "Tasks", value: "\(entry.data.totalTaskCount)")

                if !entry.data.lastMessageContent.isEmpty {
                    Divider()
                    Text(entry.data.lastMessageContent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "openclaw://dashboard"))
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}

#Preview(as: .systemSmall) {
    StatusWidget()
} timeline: {
    StatusEntry(date: .now, data: WidgetData(isConnected: true, agentName: "Claude", activeSessionCount: 3))
}

#Preview(as: .systemMedium) {
    StatusWidget()
} timeline: {
    StatusEntry(date: .now, data: WidgetData(
        isConnected: true, agentName: "Claude", modelName: "claude-sonnet-4-6",
        lastActivityTime: Date().addingTimeInterval(-300),
        activeSessionCount: 3, lastMessageContent: "I've finished implementing the auth module.",
        totalTaskCount: 12
    ))
}
