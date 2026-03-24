import SwiftUI
import WidgetKit

// MARK: - Last Message Widget (Medium)

struct LastMessageWidget: Widget {
    let kind = "LastMessageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastMessageTimelineProvider()) { entry in
            LastMessageWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Message")
        .description("Shows the most recent agent message.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline

struct LastMessageEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct LastMessageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastMessageEntry {
        LastMessageEntry(date: .now, data: WidgetData())
    }

    func getSnapshot(in context: Context, completion: @escaping (LastMessageEntry) -> Void) {
        let data = WidgetDataStore.load()
        completion(LastMessageEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastMessageEntry>) -> Void) {
        let data = WidgetDataStore.load()
        let entry = LastMessageEntry(date: .now, data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - View

struct LastMessageWidgetView: View {
    let entry: LastMessageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "bubble.left.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                if !entry.data.lastMessageSessionName.isEmpty {
                    Text(entry.data.lastMessageSessionName)
                        .font(.caption.bold())
                        .lineLimit(1)
                } else {
                    Text("Latest Message")
                        .font(.caption.bold())
                }

                Spacer()

                if let ts = entry.data.lastMessageTimestamp {
                    Text(ts, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Message content
            if entry.data.lastMessageContent.isEmpty {
                Text("No messages yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                Text(entry.data.lastMessageContent)
                    .font(.subheadline)
                    .lineLimit(4)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "openclaw://chat/\(entry.data.lastMessageSessionKey)"))
    }
}

#Preview(as: .systemMedium) {
    LastMessageWidget()
} timeline: {
    LastMessageEntry(date: .now, data: WidgetData(
        lastMessageContent: "I've completed the database migration and all tests are passing. The new schema supports the multi-tenant architecture we discussed.",
        lastMessageSessionName: "dev-session",
        lastMessageTimestamp: Date().addingTimeInterval(-120),
        lastMessageSessionKey: "abc123"
    ))
}
