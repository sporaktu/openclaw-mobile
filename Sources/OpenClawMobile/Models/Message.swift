import Foundation

// MARK: - Chat Message

struct ChatMessage: Codable, Identifiable, Sendable {
    let id: String
    let role: String                // "user", "assistant", "tool", "system"
    let content: String
    let timestamp: String?
    let sessionKey: String?

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
        case sessionKey = "session_key"
    }

    var isUser: Bool { role.lowercased() == "user" }
    var isAssistant: Bool { role.lowercased() == "assistant" }
    var isSystem: Bool { role.lowercased() == "system" }

    var formattedTime: String {
        guard let timestamp else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            return Self.timeFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestamp) {
            return Self.timeFormatter.string(from: date)
        }
        // Try Unix timestamp (ms)
        if let ms = Double(timestamp) {
            let date = Date(timeIntervalSince1970: ms / 1000)
            return Self.timeFormatter.string(from: date)
        }
        return ""
    }

    static func userMessage(_ content: String, sessionKey: String? = nil) -> ChatMessage {
        ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: content,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            sessionKey: sessionKey
        )
    }

    /// Parse from a raw dictionary (used for gateway event payloads)
    static func from(dict: [String: Any]) -> ChatMessage? {
        let role = dict["role"] as? String ?? "assistant"

        // Content can be a string or array of content blocks
        let content: String
        if let text = dict["content"] as? String {
            content = text
        } else if let blocks = dict["content"] as? [[String: Any]] {
            // Extract text from content blocks
            content = blocks.compactMap { block -> String? in
                if block["type"] as? String == "text" {
                    return block["text"] as? String
                }
                if block["type"] as? String == "thinking" {
                    return nil // skip thinking blocks
                }
                if block["type"] as? String == "tool_use" {
                    let name = block["name"] as? String ?? "tool"
                    return "[\(name)]"
                }
                return nil
            }.joined(separator: "\n")
        } else {
            return nil
        }

        let timestamp: String?
        if let ts = dict["timestamp"] as? String {
            timestamp = ts
        } else if let ts = dict["timestamp"] as? Double {
            timestamp = String(Int(ts))
        } else {
            timestamp = ISO8601DateFormatter().string(from: Date())
        }

        return ChatMessage(
            id: dict["id"] as? String ?? UUID().uuidString,
            role: role,
            content: content,
            timestamp: timestamp,
            sessionKey: dict["sessionKey"] as? String ?? dict["session_key"] as? String
        )
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Gateway Status

struct GatewayStatus: Codable, Sendable {
    let status: String?
    let version: String?
    let agentName: String?
    let uptime: String?

    enum CodingKeys: String, CodingKey {
        case status, version
        case agentName = "agent_name"
        case uptime
    }
}

// MARK: - Message Send Response

struct MessageResponse: Codable, Sendable {
    let response: String?
    let messageId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case response
        case messageId = "message_id"
        case error
    }
}
