import Foundation

// MARK: - Gateway Service (JSON-RPC 3.0 over WebSocket)

@Observable
@MainActor
final class GatewayService {
    // MARK: - Observable State

    var isConnected = false
    var isGenerating = false
    var processingStage: ProcessingStage?
    var messages: [ChatMessage] = []
    var streamingText = ""
    var currentSessionKey = ""
    var sessions: [Session] = []
    var agentName = ""
    var error: String?

    // MARK: - Private

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingRPCs: [String: CheckedContinuation<[String: Any], any Error>] = [:]
    private let instanceId = UUID().uuidString
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 20

    private var gatewayURL = ""
    private var gatewayToken = ""

    // MARK: - Configuration

    func configure(url: String, token: String) {
        self.gatewayURL = url
        self.gatewayToken = token
    }

    var isConfigured: Bool {
        !gatewayURL.isEmpty && !gatewayToken.isEmpty
    }

    // MARK: - Connection

    func connect() async throws {
        guard isConfigured else { throw GatewayError.notConfigured }
        disconnect()

        var urlString = gatewayURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasSuffix("/") { urlString.removeLast() }

        // Convert to WebSocket URL
        urlString = urlString
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        if !urlString.hasPrefix("ws://") && !urlString.hasPrefix("wss://") {
            urlString = "ws://\(urlString)"
        }

        // The gateway WebSocket endpoint (direct, no socket.io path)
        urlString += "/ws"

        guard let url = URL(string: urlString) else {
            throw GatewayError.invalidURL
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.urlSession = session
        self.webSocket = task
        task.resume()

        // Start receiving messages
        startReceiveLoop()

        // Wait for connect.challenge event, then respond
        try await performHandshake()

        isConnected = true
        reconnectAttempts = 0
        error = nil
    }

    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false

        // Fail all pending RPCs
        for (_, continuation) in pendingRPCs {
            continuation.resume(throwing: GatewayError.disconnected)
        }
        pendingRPCs.removeAll()
    }

    // MARK: - RPC

    /// Send an RPC request and wait for the response.
    func rpc(_ method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        guard let ws = webSocket else { throw GatewayError.notConnected }

        let requestId = UUID().uuidString
        var msg: [String: Any] = [
            "type": "req",
            "id": requestId,
            "method": method
        ]
        if !params.isEmpty {
            msg["params"] = params
        }

        let data = try JSONSerialization.data(withJSONObject: msg)
        let text = String(data: data, encoding: .utf8)!

        return try await withCheckedThrowingContinuation { continuation in
            pendingRPCs[requestId] = continuation

            Task {
                do {
                    try await ws.send(.string(text))
                } catch {
                    pendingRPCs.removeValue(forKey: requestId)
                    continuation.resume(throwing: error)
                }
            }

            // Timeout after 30 seconds
            Task {
                try? await Task.sleep(for: .seconds(30))
                if let cont = pendingRPCs.removeValue(forKey: requestId) {
                    cont.resume(throwing: GatewayError.rpcTimeout(method))
                }
            }
        }
    }

    // MARK: - Chat API

    func sendMessage(_ content: String, sessionKey: String? = nil) async {
        let key = sessionKey ?? currentSessionKey
        guard !key.isEmpty else {
            error = "No session selected"
            return
        }

        // Optimistic user message
        let userMsg = ChatMessage.userMessage(content, sessionKey: key)
        messages.append(userMsg)
        streamingText = ""
        isGenerating = true
        processingStage = .thinking

        do {
            let idempotencyKey = UUID().uuidString
            _ = try await rpc("chat.send", params: [
                "sessionKey": key,
                "message": content,
                "deliver": false,
                "idempotencyKey": idempotencyKey
            ])
        } catch {
            self.error = "Failed to send: \(error.localizedDescription)"
            isGenerating = false
            processingStage = nil
        }
    }

    func fetchHistory(sessionKey: String? = nil, limit: Int = 100) async {
        let key = sessionKey ?? currentSessionKey
        guard !key.isEmpty else { return }

        do {
            let result = try await rpc("chat.history", params: [
                "sessionKey": key,
                "limit": limit
            ])

            if let msgsArray = result["messages"] as? [[String: Any]] {
                let parsed = msgsArray.compactMap { ChatMessage.from(dict: $0) }
                messages = parsed
            }
        } catch {
            self.error = "Failed to fetch history: \(error.localizedDescription)"
        }
    }

    func abortGeneration(sessionKey: String? = nil) async {
        let key = sessionKey ?? currentSessionKey
        guard !key.isEmpty else { return }
        _ = try? await rpc("chat.abort", params: ["sessionKey": key])
        isGenerating = false
        processingStage = nil
    }

    // MARK: - Session API

    func listSessions() async {
        do {
            let result = try await rpc("sessions.list", params: [:])
            if let sessionsArray = result["sessions"] as? [[String: Any]] {
                sessions = sessionsArray.compactMap { Session.from(dict: $0) }
            }
        } catch {
            self.error = "Failed to list sessions: \(error.localizedDescription)"
        }
    }

    func createSession(label: String? = nil, model: String? = nil) async -> String? {
        var params: [String: Any] = [:]
        if let label { params["label"] = label }
        if let model { params["model"] = model }

        do {
            let result = try await rpc("sessions.create", params: params)
            let key = result["key"] as? String
            if let key {
                await listSessions() // refresh
            }
            return key
        } catch {
            self.error = "Failed to create session: \(error.localizedDescription)"
            return nil
        }
    }

    func deleteSession(key: String) async {
        do {
            _ = try await rpc("sessions.delete", params: ["key": key])
            sessions.removeAll { $0.sessionKey == key }
            if currentSessionKey == key {
                currentSessionKey = sessions.first?.sessionKey ?? ""
            }
        } catch {
            self.error = "Failed to delete session: \(error.localizedDescription)"
        }
    }

    func resetSession(key: String) async {
        do {
            _ = try await rpc("sessions.reset", params: ["key": key])
            if currentSessionKey == key {
                messages.removeAll()
            }
        } catch {
            self.error = "Failed to reset session: \(error.localizedDescription)"
        }
    }

    func patchSession(key: String, label: String? = nil, model: String? = nil, thinking: String? = nil) async {
        var params: [String: Any] = ["key": key]
        if let label { params["label"] = label }
        if let model { params["model"] = model }
        if let thinking { params["thinking"] = thinking }

        do {
            _ = try await rpc("sessions.patch", params: params)
            await listSessions() // refresh
        } catch {
            self.error = "Failed to update session: \(error.localizedDescription)"
        }
    }

    func switchSession(to key: String) async {
        currentSessionKey = key
        messages.removeAll()
        streamingText = ""
        isGenerating = false
        processingStage = nil
        await fetchHistory(sessionKey: key)
    }

    // MARK: - Status

    func fetchStatus() async {
        do {
            let result = try await rpc("status", params: [:])
            if let h = result["h"] as? [String: Any],
               let agent = h["agent"] as? [String: Any],
               let model = agent["model"] as? String {
                agentName = model
            } else if let model = result["model"] as? String {
                agentName = model
            }
        } catch {
            // Status is non-critical, don't surface error
        }
    }

    // MARK: - Private: Handshake

    private func performHandshake() async throws {
        // Wait for connect.challenge event (handled in receiveLoop)
        // The challenge comes as an event; we respond with connect RPC
        // Give it a few seconds to arrive
        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(100))
            if challengeReceived { break }
        }

        // Send connect request
        let connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "openclaw-mobile",
                "version": "1.0.0",
                "platform": "ios",
                "mode": "webchat",
                "instanceId": instanceId
            ],
            "role": "operator",
            "scopes": ["operator.admin", "operator.read", "operator.write", "operator.approvals"],
            "auth": ["token": gatewayToken],
            "caps": ["tool-events"]
        ]

        let result = try await rpc("connect", params: connectParams)

        guard result["ok"] as? Bool == true else {
            let errMsg = result["error"] as? String ?? "Unknown error"
            throw GatewayError.authFailed
        }
    }

    private var challengeReceived = false

    // MARK: - Private: WebSocket Receive Loop

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let ws = await self.webSocket else { break }
                do {
                    let message = try await ws.receive()
                    switch message {
                    case .string(let text):
                        await self.handleRawMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            await self.handleRawMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    await MainActor.run {
                        self.isConnected = false
                        self.error = "WebSocket error: \(error.localizedDescription)"
                    }
                    await self.attemptReconnect()
                    break
                }
            }
        }
    }

    private func handleRawMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let type = json["type"] as? String

        switch type {
        case "res":
            // RPC response — resolve pending continuation
            if let id = json["id"] as? String,
               let continuation = pendingRPCs.removeValue(forKey: id) {
                continuation.resume(returning: json)
            }

        case "event":
            let eventName = json["event"] as? String
            let payload = json["payload"] as? [String: Any]

            switch eventName {
            case "connect.challenge":
                challengeReceived = true

            case "chat":
                if let payload {
                    handleChatEvent(payload)
                }

            case "agent":
                if let payload {
                    handleAgentEvent(payload)
                }

            default:
                break
            }

        default:
            break
        }
    }

    // MARK: - Private: Chat Events

    private func handleChatEvent(_ payload: [String: Any]) {
        guard let event = ChatEventPayload(from: payload) else { return }

        // Only handle events for current session
        if let key = event.sessionKey, key != currentSessionKey { return }

        switch event.state {
        case "started":
            isGenerating = true
            processingStage = .thinking
            streamingText = ""

        case "delta":
            processingStage = .streaming
            if let delta = event.deltaText {
                streamingText += delta
            }

        case "final":
            isGenerating = false
            processingStage = nil
            // Replace streaming text with final messages
            if let finalMessages = event.messages {
                // Remove any previous streaming placeholder
                // Append only assistant messages from final
                let assistantMessages = finalMessages.filter { $0.isAssistant }
                for msg in assistantMessages {
                    // Don't duplicate if already in messages
                    if !messages.contains(where: { $0.id == msg.id }) {
                        messages.append(msg)
                    }
                }
            } else if !streamingText.isEmpty {
                // Fallback: use streamed text as the message
                let msg = ChatMessage(
                    id: UUID().uuidString,
                    role: "assistant",
                    content: streamingText,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    sessionKey: currentSessionKey
                )
                messages.append(msg)
            }
            streamingText = ""

        case "error":
            isGenerating = false
            processingStage = nil
            streamingText = ""
            let errMsg = event.errorMessage ?? event.error ?? "Unknown error"
            error = errMsg

        case "aborted":
            isGenerating = false
            processingStage = nil
            if !streamingText.isEmpty {
                let msg = ChatMessage(
                    id: UUID().uuidString,
                    role: "assistant",
                    content: streamingText + "\n\n[aborted]",
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    sessionKey: currentSessionKey
                )
                messages.append(msg)
            }
            streamingText = ""

        default:
            break
        }
    }

    // MARK: - Private: Agent Events

    private func handleAgentEvent(_ payload: [String: Any]) {
        guard let event = AgentEventPayload(from: payload) else { return }

        // Update processing stage based on agent state
        if let agentState = event.agentState {
            switch agentState {
            case "thinking", "processing":
                processingStage = .thinking
            case "tool_use":
                processingStage = .toolUse
            case "streaming":
                processingStage = .streaming
            default:
                break
            }
        }
    }

    // MARK: - Private: Reconnect

    private func attemptReconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            error = "Failed to reconnect after \(maxReconnectAttempts) attempts"
            return
        }

        reconnectAttempts += 1
        let delay = min(30.0, pow(1.5, Double(reconnectAttempts)))
        try? await Task.sleep(for: .seconds(delay))

        do {
            try await connect()
        } catch {
            // Will retry via receive loop failure
        }
    }
}
