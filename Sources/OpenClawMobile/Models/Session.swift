import Foundation

/// Represents a chat session from the gateway.
struct Session: Codable, Identifiable, Sendable {
    var id: String { sessionKey }

    let sessionKey: String
    var label: String?
    var state: String?          // "idle", "thinking", "done", "error"
    var agentState: String?
    var busy: Bool?
    var lastActivity: String?
    var updatedAt: Double?      // Unix timestamp ms
    var model: String?
    var thinking: String?       // "off", "low", "medium", "high"
    var totalTokens: Int?
    var contextTokens: Int?
    var channel: String?
    var kind: String?
    var displayName: String?
    var parentId: String?       // non-nil = sub-agent

    var isSubAgent: Bool { parentId != nil }

    var effectiveLabel: String {
        label ?? displayName ?? sessionKey
    }

    var isActive: Bool {
        guard let s = state ?? agentState else { return false }
        return ["thinking", "processing", "tool_use", "streaming", "started"].contains(s)
    }

    var lastActivityDate: Date? {
        if let ts = updatedAt {
            return Date(timeIntervalSince1970: ts / 1000)
        }
        guard let str = lastActivity else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    /// Parse from gateway dictionary
    static func from(dict: [String: Any]) -> Session? {
        let key = dict["sessionKey"] as? String
            ?? dict["key"] as? String
            ?? dict["id"] as? String
        guard let sessionKey = key else { return nil }

        return Session(
            sessionKey: sessionKey,
            label: dict["label"] as? String,
            state: dict["state"] as? String,
            agentState: dict["agentState"] as? String,
            busy: dict["busy"] as? Bool,
            lastActivity: dict["lastActivity"] as? String,
            updatedAt: dict["updatedAt"] as? Double,
            model: dict["model"] as? String,
            thinking: dict["thinking"] as? String,
            totalTokens: dict["totalTokens"] as? Int,
            contextTokens: dict["contextTokens"] as? Int,
            channel: dict["channel"] as? String,
            kind: dict["kind"] as? String,
            displayName: dict["displayName"] as? String,
            parentId: dict["parentId"] as? String
        )
    }
}
