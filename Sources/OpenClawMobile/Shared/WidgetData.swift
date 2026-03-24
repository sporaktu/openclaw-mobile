import Foundation

// MARK: - Shared Widget Data

/// App Group identifier for sharing data between the main app and widgets.
let appGroupId = "group.com.openclaw.mobile"

/// Data shared between the main app and WidgetKit widgets via UserDefaults.
/// The main app writes this on every gateway update; widgets read it.
struct WidgetData: Codable {
    // Status
    var isConnected: Bool = false
    var agentName: String = ""
    var modelName: String = ""
    var gatewayVersion: String = ""
    var lastActivityTime: Date?
    var activeSessionCount: Int = 0

    // Last message
    var lastMessageContent: String = ""
    var lastMessageSessionName: String = ""
    var lastMessageTimestamp: Date?
    var lastMessageSessionKey: String = ""

    // Tasks
    var taskCountByStatus: [String: Int] = [:]
    var topInProgressTasks: [WidgetTaskInfo] = []
    var totalTaskCount: Int = 0
}

struct WidgetTaskInfo: Codable, Identifiable {
    var id: String
    var title: String
    var priority: String
}

// MARK: - UserDefaults Helpers

enum WidgetDataStore {
    private static let key = "widgetData"

    static var shared: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func save(_ data: WidgetData) {
        guard let defaults = shared,
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
    }

    static func load() -> WidgetData {
        guard let defaults = shared,
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return WidgetData()
        }
        return decoded
    }
}
