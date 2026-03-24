import Foundation

// MARK: - Widget Data Writer (Main App Side)

/// Called from the main app to push latest state to the widget's shared UserDefaults.
/// Should be called whenever gateway state changes significantly.
@MainActor
enum WidgetDataWriter {

    static func update(
        gateway: GatewayService,
        kanbanService: KanbanService
    ) {
        var data = WidgetData()

        // Status
        data.isConnected = gateway.isConnected
        data.agentName = gateway.agentName
        data.activeSessionCount = gateway.sessions.count

        // Last message
        if let lastMsg = gateway.messages.last(where: { $0.isAssistant }) {
            data.lastMessageContent = String(lastMsg.content.prefix(200))
            data.lastMessageSessionKey = lastMsg.sessionKey ?? ""
            data.lastMessageSessionName = gateway.sessions
                .first(where: { $0.sessionKey == lastMsg.sessionKey })?.effectiveLabel ?? ""
            if let ts = lastMsg.timestamp {
                let fmt = ISO8601DateFormatter()
                fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                data.lastMessageTimestamp = fmt.date(from: ts)
                if data.lastMessageTimestamp == nil {
                    fmt.formatOptions = [.withInternetDateTime]
                    data.lastMessageTimestamp = fmt.date(from: ts)
                }
            }
        }

        data.lastActivityTime = Date()

        // Tasks
        let counts = kanbanService.statusCounts
        data.taskCountByStatus = Dictionary(uniqueKeysWithValues: counts.map { ($0.key.rawValue, $0.value) })
        data.totalTaskCount = kanbanService.tasks.count
        data.topInProgressTasks = kanbanService.inProgressTasks.prefix(3).map {
            WidgetTaskInfo(id: $0.id, title: $0.title, priority: $0.priority.rawValue)
        }

        WidgetDataStore.save(data)
    }
}
