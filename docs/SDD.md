# Software Design Document — OpenClaw Mobile Phase 1

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. System Architecture](#2-system-architecture)
- [3. Data Models](#3-data-models)
- [4. Service Layer Design](#4-service-layer-design)
- [5. View Architecture](#5-view-architecture)
- [6. Widget Architecture](#6-widget-architecture)
- [7. State Management](#7-state-management)
- [8. Error Handling Strategy](#8-error-handling-strategy)
- [9. Security](#9-security)
- [10. Project Structure](#10-project-structure)
- [11. Implementation Plan](#11-implementation-plan)

---

## 1. Introduction

### 1.1 Purpose

OpenClaw Mobile is a native iOS app that mirrors the Nerve web dashboard, providing mobile access to an OpenClaw AI agent via the gateway WebSocket protocol. Phase 1 delivers: enhanced chat (multi-session, streaming), session management, and cron management.

### 1.2 Scope

Phase 1 covers:
- Multi-session chat with streaming token display and markdown rendering
- Session CRUD (list, create, delete, reset, patch)
- Cron job management (list, create, edit, toggle, manual run, run history)
- Tab-based navigation (Chat, Sessions, Crons, Settings)

Out of scope for Phase 1: memory browser, kanban, widgets, notifications, file browser, voice.

### 1.3 Definitions

| Term | Definition |
|------|-----------|
| Gateway | OpenClaw WebSocket server (JSON-RPC 3.0 over WS) |
| Session | A chat conversation context with its own message history |
| Cron | A scheduled task that triggers agent actions on a timer |
| RPC | Remote Procedure Call — request/response over WebSocket |
| Event | Server-pushed message over WebSocket (no request) |

### 1.4 Key Discovery: Protocol Mismatch

The existing `GatewayService.swift` implements raw socket.io frame parsing (`42["event", {}]`). The Nerve web dashboard actually uses **JSON-RPC 3.0** with a challenge-based handshake. The gateway service must be refactored to use the correct protocol:

```
// Correct protocol (JSON-RPC 3.0)
→ Server: { "type": "event", "event": "connect.challenge" }
← Client: { "type": "req", "id": "...", "method": "connect", "params": { ... } }
→ Server: { "type": "res", "id": "...", "ok": true }

// RPC call
← Client: { "type": "req", "id": "...", "method": "chat.send", "params": { ... } }
→ Server: { "type": "res", "id": "...", ... }

// Server event
→ Server: { "type": "event", "event": "chat", "payload": { ... } }
```

Additionally, crons, memory, and kanban use **REST APIs** (not WebSocket events).

---

## 2. System Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────┐
│                  OpenClaw Mobile                     │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ ChatView │  │ Sessions │  │ CronsView│          │
│  │(Enhanced)│  │  View    │  │          │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       │              │              │                │
│  ┌────▼──────────────▼──────────────▼────┐          │
│  │          GatewayService (refactored)   │          │
│  │   ┌─────────────────────────────┐     │          │
│  │   │  JSON-RPC 3.0 Transport     │     │          │
│  │   │  • Challenge handshake      │     │          │
│  │   │  • RPC request/response     │     │          │
│  │   │  • Event streaming          │     │          │
│  │   │  • Auto-reconnect           │     │          │
│  │   └─────────────────────────────┘     │          │
│  └───────────────┬───────────────────────┘          │
│                  │                                   │
│  ┌───────────────▼───────────────────────┐          │
│  │          REST API Client               │          │
│  │  • CronService (REST /api/crons)      │          │
│  │  • Future: MemoryService, KanbanSvc   │          │
│  └───────────────┬───────────────────────┘          │
│                  │                                   │
│  ┌───────────────▼───────────────────────┐          │
│  │          AppConfiguration              │          │
│  │  • Gateway URL + Token (Keychain)     │          │
│  │  • Session preferences (@AppStorage)  │          │
│  └───────────────────────────────────────┘          │
└──────────────────┬──────────────────────────────────┘
                   │ WSS + HTTPS
          ┌────────▼────────┐
          │  OpenClaw        │
          │  Gateway         │
          │  (:18789)        │
          └─────────────────┘
```

### 2.2 Data Flow

```
User Action → View → Service Method (async) → WebSocket RPC / REST
                                                    │
Server Response ← Service @Observable state ← ─────┘
                                                    │
Server Event ──→ Service event handler ──→ @Observable state update
                                                    │
                                        View re-renders automatically
```

### 2.3 Dependency Graph

```
Views ──→ Services ──→ Configuration
  │                        │
  └── Theme (standalone)   └── Keychain (standalone)
```

No circular dependencies. Views depend on services. Services depend on configuration. Theme is standalone.

---

## 3. Data Models

### 3.1 Gateway Protocol Models

```swift
// MARK: - JSON-RPC 3.0 Transport

struct GatewayMessage: Codable, Sendable {
    let type: String                    // "req", "res", "event"
    var id: String?                     // request/response correlation
    var method: String?                 // RPC method name
    var params: [String: AnyCodable]?   // RPC params
    var event: String?                  // event name
    var payload: AnyCodable?            // event payload
    var ok: Bool?                       // response success
    var error: String?                  // response error
    var seq: Int?                       // sequence number
}

struct ConnectParams: Codable, Sendable {
    let minProtocol: Int                // 3
    let maxProtocol: Int                // 3
    let client: ClientInfo
    let role: String                    // "operator"
    let scopes: [String]
    let auth: AuthParams
    let caps: [String]
}

struct ClientInfo: Codable, Sendable {
    let id: String                      // "openclaw-mobile"
    let version: String                 // app version
    let platform: String                // "ios"
    let mode: String                    // "webchat"
    let instanceId: String              // UUID per install
}

struct AuthParams: Codable, Sendable {
    let token: String
}
```

### 3.2 Chat Models

```swift
struct ChatMessage: Codable, Identifiable, Sendable {
    let id: String
    let role: String                    // "user", "assistant", "tool", "system"
    let content: ChatContent            // String or [ContentBlock]
    let timestamp: String?
    let sessionKey: String?

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

enum ChatContent: Codable, Sendable {
    case text(String)
    case blocks([ContentBlock])
}

struct ContentBlock: Codable, Sendable {
    let type: String                    // "text", "tool_use", "tool_result", "thinking"
    var text: String?
    var name: String?                   // tool name
    var input: [String: AnyCodable]?    // tool args
    var id: String?                     // tool call id
}

struct ChatEventPayload: Codable, Sendable {
    let sessionKey: String?
    let state: String                   // "started", "delta", "final", "error", "aborted"
    var runId: String?
    var seq: Int?
    var message: AnyCodable?            // String for delta, ChatMessage for final
    var messages: [ChatMessage]?        // final messages array
    var stopReason: String?
    var error: String?
    var errorMessage: String?
}
```

### 3.3 Session Models

```swift
struct Session: Codable, Identifiable, Sendable {
    var id: String { sessionKey }
    let sessionKey: String
    var label: String?
    var state: String?                  // "idle", "thinking", "done", "error"
    var agentState: String?
    var busy: Bool?
    var lastActivity: String?
    var model: String?
    var thinking: String?               // "off", "low", "medium", "high"
    var totalTokens: Int?
    var contextTokens: Int?
    var channel: String?
    var kind: String?
    var displayName: String?
    var parentId: String?               // non-nil = sub-agent

    var isSubAgent: Bool { parentId != nil }
    var effectiveLabel: String { label ?? displayName ?? sessionKey }
    var isActive: Bool {
        ["thinking", "processing", "tool_use", "streaming"].contains(state ?? "")
    }
}
```

### 3.4 Cron Models

```swift
struct CronJob: Codable, Identifiable, Sendable {
    let id: String
    var name: String?
    var label: String?
    var enabled: Bool

    // Schedule
    var scheduleKind: String            // "every", "cron", "at"
    var schedule: String?               // cron expression
    var scheduleTz: String?
    var everyMs: Int?                   // interval milliseconds
    var at: String?                     // ISO datetime

    // Payload
    var payloadKind: String             // "agentTurn", "systemEvent"
    var message: String?
    var model: String?

    // State
    var lastRun: String?
    var lastStatus: String?
    var lastError: String?

    var effectiveName: String { name ?? label ?? id }
    var humanSchedule: String {
        switch scheduleKind {
        case "every":
            guard let ms = everyMs else { return "unknown" }
            let minutes = ms / 60_000
            if minutes < 60 { return "Every \(minutes)m" }
            return "Every \(minutes / 60)h"
        case "cron":
            return schedule ?? "unknown"
        case "at":
            return at ?? "one-time"
        default:
            return "unknown"
        }
    }
}

struct CronRun: Codable, Identifiable, Sendable {
    var id: String { timestamp }
    let timestamp: String
    let status: String                  // "success", "error", "timeout"
    var duration: Int?                  // ms
    var error: String?
    var summary: String?
}

struct CreateCronPayload: Codable, Sendable {
    let name: String
    let scheduleKind: String
    var schedule: String?
    var everyMs: Int?
    let payloadKind: String
    let message: String
    var model: String?
    let enabled: Bool
}
```

### 3.5 Utility: AnyCodable

A type-erased `Codable` wrapper for heterogeneous JSON payloads — needed because the gateway sends mixed-type dictionaries.

```swift
struct AnyCodable: Codable, Sendable {
    let value: Any  // Must be JSON-compatible

    // Encode/decode via JSONSerialization bridge
    // Convenience accessors: .string, .int, .bool, .dict, .array
}
```

---

## 4. Service Layer Design

### 4.1 GatewayService Refactoring

The existing `GatewayService` must be refactored from socket.io frame parsing to JSON-RPC 3.0.

**Current** (broken): Parses `42["event", {}]` frames, sends `40{auth:{}}` for connect.
**Target**: Parses `{"type":"event","event":"chat","payload":{}}` JSON messages, uses challenge handshake.

```swift
@Observable
@MainActor
final class GatewayService {
    // MARK: - Published State
    var isConnected = false
    var isGenerating = false
    var processingStage: ProcessingStage? = nil  // thinking, streaming, tool_use
    var messages: [ChatMessage] = []
    var streamingText = ""
    var currentSessionKey: String = ""
    var sessions: [Session] = []
    var agentName = ""
    var error: String?

    // MARK: - Private
    private var webSocket: URLSessionWebSocketTask?
    private var pendingRequests: [String: CheckedContinuation<GatewayMessage, Error>] = [:]
    private let instanceId = UUID().uuidString

    // MARK: - Connection
    func connect() async throws          // Challenge handshake
    func disconnect()                    // Close WebSocket

    // MARK: - RPC (generic)
    func rpc(_ method: String, params: [String: Any]) async throws -> GatewayMessage

    // MARK: - Chat
    func sendMessage(_ content: String, sessionKey: String) async throws
    func fetchHistory(sessionKey: String, limit: Int?) async throws -> [ChatMessage]
    func abortGeneration(sessionKey: String) async throws

    // MARK: - Sessions
    func listSessions() async throws -> [Session]
    func createSession(label: String?, model: String?) async throws -> String
    func deleteSession(key: String) async throws
    func resetSession(key: String) async throws
    func patchSession(key: String, label: String?, model: String?) async throws

    // MARK: - Event Handling (private)
    private func handleEvent(_ message: GatewayMessage)
    private func handleChatEvent(_ payload: ChatEventPayload)
    private func receiveLoop()           // Continuous WebSocket read
    private func startPingTimer()        // Keep-alive
}

enum ProcessingStage: String, Sendable {
    case thinking, streaming, toolUse = "tool_use"
}
```

### 4.2 CronService (REST)

Crons use REST endpoints, not WebSocket. Separate service.

```swift
@Observable
@MainActor
final class CronService {
    var jobs: [CronJob] = []
    var isLoading = false
    var error: String?

    private let baseURL: String
    private let token: String

    func fetchJobs() async throws -> [CronJob]
    func createJob(_ payload: CreateCronPayload) async throws
    func updateJob(id: String, patch: [String: Any]) async throws
    func deleteJob(id: String) async throws
    func toggleJob(id: String, enabled: Bool) async throws
    func runJob(id: String) async throws
    func fetchRuns(id: String) async throws -> [CronRun]

    // Private
    private func request<T: Decodable>(
        _ method: String, path: String, body: Encodable?
    ) async throws -> T
}
```

### 4.3 Event Contracts

#### Chat RPC

| Method | Request Params | Response |
|--------|---------------|----------|
| `chat.send` | `{ sessionKey, message, deliver: false, idempotencyKey }` | `{ runId?, status? }` |
| `chat.history` | `{ sessionKey, limit? }` | `{ messages: [ChatMessage] }` |
| `chat.abort` | `{ sessionKey }` | `{ ok: true }` |

#### Chat Events (server → client)

| Event | State | Payload |
|-------|-------|---------|
| `chat` | `started` | `{ sessionKey, runId }` |
| `chat` | `delta` | `{ sessionKey, message: "token text" }` |
| `chat` | `final` | `{ sessionKey, messages: [ChatMessage] }` |
| `chat` | `error` | `{ sessionKey, error, errorMessage }` |
| `chat` | `aborted` | `{ sessionKey }` |

#### Session RPC

| Method | Request Params | Response |
|--------|---------------|----------|
| `sessions.list` | `{ activeMinutes?, limit? }` | `{ sessions: [Session] }` |
| `sessions.create` | `{ label?, model? }` | `{ key: string }` |
| `sessions.delete` | `{ key }` | `{ ok: true }` |
| `sessions.reset` | `{ key }` | `{ ok: true }` |
| `sessions.patch` | `{ key, label?, model? }` | `{ ok: true }` |

#### Cron REST

| Verb | Path | Body | Response |
|------|------|------|----------|
| GET | `/api/crons` | — | `{ ok, result: { jobs } }` |
| POST | `/api/crons` | `{ job: CreateCronPayload }` | `{ ok }` |
| PATCH | `/api/crons/{id}` | `{ patch: {...} }` | `{ ok }` |
| DELETE | `/api/crons/{id}` | — | `{ ok }` |
| POST | `/api/crons/{id}/toggle` | `{ enabled: Bool }` | `{ ok }` |
| POST | `/api/crons/{id}/run` | — | `{ ok }` |
| GET | `/api/crons/{id}/runs` | — | `{ ok, result: { runs } }` |

---

## 5. View Architecture

### 5.1 View Hierarchy

```
OpenClawMobileApp
└── ContentView (TabView)
    ├── Tab: Chat
    │   └── ChatContainerView
    │       ├── SessionPickerBar (horizontal scroll of sessions)
    │       ├── ChatView (message list)
    │       │   └── MessageBubble (per message)
    │       │       ├── MarkdownText (rendered markdown)
    │       │       └── StreamingIndicator (dots/cursor)
    │       └── ChatInputBar (text field + send)
    │
    ├── Tab: Sessions
    │   └── NavigationStack
    │       ├── SessionsListView
    │       │   └── SessionRow (per session)
    │       └── SessionDetailView (edit label, model, delete)
    │
    ├── Tab: Crons
    │   └── NavigationStack
    │       ├── CronsListView
    │       │   └── CronRow (per job)
    │       ├── CronDetailView (view/edit job)
    │       │   └── CronRunsView (run history)
    │       └── CreateCronView (new job form)
    │
    └── Tab: Settings
        └── SettingsView (existing, enhanced)
```

### 5.2 Navigation Flow

- **Chat tab**: Flat — session picker bar at top, messages below, input at bottom. No push navigation.
- **Sessions tab**: NavigationStack — list → detail (push). Tapping a session switches to Chat tab with that session active.
- **Crons tab**: NavigationStack — list → detail (push), or list → create (sheet).
- **Settings tab**: Single view (existing).

### 5.3 State Management Per View

| View | State Source | Local State |
|------|-------------|-------------|
| ChatContainerView | `GatewayService.messages`, `.sessions`, `.currentSessionKey` | `messageText`, `scrollPosition` |
| SessionsListView | `GatewayService.sessions` | `searchText`, `showCreateSheet` |
| CronsListView | `CronService.jobs` | `searchText`, `showCreateSheet` |
| CronDetailView | `CronService` (single job) | `editedFields`, `showRunHistory` |
| CreateCronView | — | form fields |

---

## 6. Widget Architecture

> Phase 3 scope. Not implemented in Phase 1.

Planned: App Group shared data store, `TimelineProvider` for each widget, REST polling (not WebSocket).

---

## 7. State Management

### 7.1 Observable Services

All services use `@Observable` (iOS 17+). No `ObservableObject`/`@Published`.

```swift
@Observable @MainActor final class GatewayService { ... }
@Observable @MainActor final class CronService { ... }
```

### 7.2 Environment Injection

```swift
// In App entry point:
@State private var gateway = GatewayService()
@State private var cronService = CronService()

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(gateway)
            .environment(cronService)
    }
}

// In views:
@Environment(GatewayService.self) private var gateway
```

### 7.3 Storage Decisions

| Data | Storage |
|------|---------|
| Gateway token | Keychain |
| Gateway URL | `@AppStorage` |
| Last session key | `@AppStorage` |
| UI preferences | `@AppStorage` |
| Message cache | In-memory (re-fetched on connect) |
| Session list | In-memory (re-fetched on connect) |
| Cron jobs | In-memory (re-fetched on tab appear) |

---

## 8. Error Handling Strategy

### 8.1 Connection Errors

```swift
enum GatewayError: LocalizedError {
    case notConfigured
    case connectionFailed(String)
    case challengeFailed
    case authFailed
    case rpcTimeout(String)
    case rpcError(String)
    case disconnected
}
```

### 8.2 Retry Strategy

- **WebSocket reconnect**: Exponential backoff (1s, 1.5s, 2.25s, ..., max 30s), up to 20 attempts.
- **RPC timeout**: 30 seconds per call. No automatic retry (caller decides).
- **REST errors**: Surface to UI. No automatic retry.

### 8.3 UI Error Presentation

- Connection errors: Banner at top of screen with retry button.
- RPC errors: Inline error message in the relevant view.
- Chat errors: Error message bubble in chat stream.

---

## 9. Security

### 9.1 Keychain for Tokens

The gateway token must move from `@AppStorage` to Keychain. Simple Keychain wrapper:

```swift
enum KeychainService {
    static func save(key: String, value: String) throws
    static func load(key: String) throws -> String?
    static func delete(key: String) throws
}
```

### 9.2 Transport Security

- All connections over WSS/HTTPS (enforced by ATS).
- Token sent in WebSocket handshake auth params and REST `Authorization: Bearer` header.
- No sensitive data in `@AppStorage` or UserDefaults.

---

## 10. Project Structure

### 10.1 Current State

SPM library package — cannot build as an iOS app. No app entry point in build system.

### 10.2 Target State

Xcode project with:
- **App target**: `OpenClawMobile` (iOS app)
- **Widget target**: `OpenClawWidgets` (WidgetKit extension) — Phase 3
- **Shared code**: Kept in `Sources/OpenClawMobile/` — no separate framework needed for Phase 1

### 10.3 File Structure (Phase 1)

```
OpenClawMobile.xcodeproj/
Sources/OpenClawMobile/
├── App/
│   ├── OpenClawMobileApp.swift          (modify: @Observable, environment)
│   └── ContentView.swift                (modify: new tabs)
├── Models/
│   ├── Message.swift                    (modify: ChatContent, ContentBlock)
│   ├── Session.swift                    (NEW)
│   ├── CronJob.swift                    (NEW)
│   ├── GatewayProtocol.swift            (NEW: GatewayMessage, ConnectParams)
│   ├── AnyCodable.swift                 (NEW)
│   ├── Entity.swift                     (existing)
│   ├── GraphData.swift                  (existing)
│   └── Task.swift                       (existing)
├── Services/
│   ├── GatewayService.swift             (REWRITE: JSON-RPC 3.0)
│   ├── CronService.swift                (NEW: REST client)
│   ├── KeychainService.swift            (NEW)
│   ├── Configuration.swift              (modify: Keychain integration)
│   └── KnowledgeGraphService.swift      (existing)
├── Views/
│   ├── Chat/
│   │   ├── ChatContainerView.swift      (NEW: session picker + chat)
│   │   ├── ChatView.swift               (modify: streaming, markdown)
│   │   ├── ChatInputBar.swift           (existing)
│   │   ├── MessageBubble.swift          (modify: markdown rendering)
│   │   └── StreamingIndicator.swift     (NEW)
│   ├── Sessions/
│   │   ├── SessionsListView.swift       (NEW)
│   │   ├── SessionRow.swift             (NEW)
│   │   └── SessionDetailView.swift      (NEW)
│   ├── Crons/
│   │   ├── CronsListView.swift          (NEW)
│   │   ├── CronRow.swift                (NEW)
│   │   ├── CronDetailView.swift         (NEW)
│   │   ├── CronRunsView.swift           (NEW)
│   │   └── CreateCronView.swift         (NEW)
│   ├── Components/
│   │   ├── ConnectionIndicator.swift    (existing)
│   │   ├── StatusBadge.swift            (existing)
│   │   └── MarkdownText.swift           (NEW: basic markdown renderer)
│   ├── Graph/                           (existing, unchanged)
│   ├── Tasks/                           (existing, unchanged)
│   └── Settings/
│       └── SettingsView.swift           (modify: Keychain fields)
└── Theme/
    └── AppTheme.swift                   (existing, minor additions)
```

---

## 11. Implementation Plan

### Phase 1A: Foundation (must complete first)

1. Create `AnyCodable.swift` — type-erased Codable wrapper
2. Create `GatewayProtocol.swift` — all gateway message types
3. Create `Session.swift` — session model
4. Create `CronJob.swift` — cron models
5. Update `Message.swift` — add `ChatContent`, `ContentBlock`, `ChatEventPayload`
6. Create `KeychainService.swift` — simple Keychain CRUD
7. Rewrite `GatewayService.swift` — JSON-RPC 3.0 with challenge handshake, RPC, events, reconnect
8. Create `CronService.swift` — REST client for /api/crons
9. Update `Configuration.swift` — Keychain for token, keep @AppStorage for URL
10. Update `OpenClawMobileApp.swift` — @Observable services, environment injection

### Phase 1B: Chat Enhancement (depends on 1A)

11. Create `StreamingIndicator.swift`
12. Create `MarkdownText.swift` — basic markdown rendering (bold, italic, code, links)
13. Update `MessageBubble.swift` — use MarkdownText, copy button, streaming state
14. Update `ChatView.swift` — multi-session messages, streaming text display, pull-to-refresh
15. Create `ChatContainerView.swift` — session picker bar + ChatView + input

### Phase 1C: Session Management (depends on 1A)

16. Create `SessionRow.swift`
17. Create `SessionsListView.swift` — list, search, create button
18. Create `SessionDetailView.swift` — edit label, model, delete, reset

### Phase 1D: Cron Management (depends on 1A: CronService)

19. Create `CronRow.swift`
20. Create `CronsListView.swift` — list with toggle, manual run
21. Create `CronDetailView.swift` — edit form + run history link
22. Create `CronRunsView.swift` — list of past runs
23. Create `CreateCronView.swift` — new cron form

### Phase 1E: Integration (depends on 1B, 1C, 1D)

24. Update `ContentView.swift` — new tab layout (Chat, Sessions, Crons, Settings)
25. Update `SettingsView.swift` — Keychain token field, remove session key (moved to chat)
26. Wire session switching: tapping session in Sessions tab → switches Chat tab session

### Sub-Agent Task Assignments

| Agent | Files Owned | Depends On |
|-------|------------|------------|
| Foundation | Steps 1–10 | — |
| Chat | Steps 11–15 | Foundation |
| Sessions | Steps 16–18 | Foundation |
| Crons | Steps 19–23 | Foundation |
| Integration | Steps 24–26 | Chat, Sessions, Crons |
