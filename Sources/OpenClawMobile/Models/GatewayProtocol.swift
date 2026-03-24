import Foundation

// MARK: - JSON-RPC 3.0 Gateway Protocol

/// A message sent to or received from the OpenClaw gateway.
/// The gateway uses JSON-RPC 3.0 over WebSocket with three message types:
/// - `req`: Client → Server RPC request
/// - `res`: Server → Client RPC response
/// - `event`: Server → Client pushed event
struct GatewayMessage: Codable, Sendable {
    let type: String
    var id: String?
    var method: String?
    var params: [String: AnyCodable]?
    var event: String?
    var payload: AnyCodable?
    var ok: Bool?
    var error: String?
    var seq: Int?
}

// MARK: - Connection Handshake

struct ConnectParams: Codable, Sendable {
    let minProtocol: Int
    let maxProtocol: Int
    let client: ClientInfo
    let role: String
    let scopes: [String]
    let auth: AuthParams
    let caps: [String]
}

struct ClientInfo: Codable, Sendable {
    let id: String
    let version: String
    let platform: String
    let mode: String
    let instanceId: String
}

struct AuthParams: Codable, Sendable {
    let token: String
}

// MARK: - Chat Event Payload

struct ChatEventPayload: Sendable {
    let sessionKey: String?
    let state: String          // "started", "delta", "final", "error", "aborted"
    var runId: String?
    var seq: Int?
    var deltaText: String?     // for delta state — the incremental token
    var messages: [ChatMessage]? // for final state — complete messages
    var error: String?
    var errorMessage: String?

    /// Parse from raw dictionary payload
    init?(from dict: [String: Any]) {
        guard let state = dict["state"] as? String else { return nil }
        self.state = state
        self.sessionKey = dict["sessionKey"] as? String
        self.runId = dict["runId"] as? String
        self.seq = dict["seq"] as? Int
        self.error = dict["error"] as? String
        self.errorMessage = dict["errorMessage"] as? String

        // Delta: message can be a string (token text)
        if state == "delta" {
            if let msg = dict["message"] as? String {
                self.deltaText = msg
            } else if let msgDict = dict["message"] as? [String: Any],
                      let content = msgDict["content"] as? String {
                self.deltaText = content
            }
        }

        // Final: messages array
        if state == "final", let msgsArray = dict["messages"] as? [[String: Any]] {
            self.messages = msgsArray.compactMap { ChatMessage.from(dict: $0) }
        }
    }
}

// MARK: - Agent Event Payload

struct AgentEventPayload: Sendable {
    let sessionKey: String?
    let stream: String?        // "lifecycle", "tool", "assistant"
    let agentState: String?    // "thinking", "tool_use", "processing"
    let toolName: String?
    let toolPhase: String?     // "start", "result"

    init?(from dict: [String: Any]) {
        self.sessionKey = dict["sessionKey"] as? String
        self.stream = dict["stream"] as? String
        self.agentState = dict["agentState"] as? String ?? dict["state"] as? String

        if let data = dict["data"] as? [String: Any] {
            self.toolName = data["name"] as? String
            self.toolPhase = data["phase"] as? String
        } else {
            self.toolName = nil
            self.toolPhase = nil
        }
    }
}

// MARK: - Processing Stage

enum ProcessingStage: String, Sendable {
    case thinking
    case streaming
    case toolUse = "tool_use"
}

// MARK: - Gateway Error

enum GatewayError: Error, LocalizedError {
    case notConnected
    case notConfigured
    case invalidURL
    case connectionFailed(String)
    case challengeFailed
    case authFailed
    case rpcTimeout(String)
    case rpcError(String)
    case disconnected

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to gateway"
        case .notConfigured: "Gateway not configured"
        case .invalidURL: "Invalid gateway URL"
        case .connectionFailed(let msg): "Connection failed: \(msg)"
        case .challengeFailed: "Challenge handshake failed"
        case .authFailed: "Authentication failed"
        case .rpcTimeout(let method): "RPC timeout: \(method)"
        case .rpcError(let msg): "RPC error: \(msg)"
        case .disconnected: "Disconnected from gateway"
        }
    }
}
