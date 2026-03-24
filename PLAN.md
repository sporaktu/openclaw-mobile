# OpenClaw Mobile — Build Plan

## Goal

Native iOS app + widgets that mirrors the core Nerve dashboard functionality, built on the `abhione/openclaw-mobile` fork.

## Starting Point

Forked from `abhione/openclaw-mobile` — 2,669 lines of SwiftUI, already has:
- ✅ WebSocket connection to gateway (socket.io protocol)
- ✅ Chat view with message bubbles
- ✅ Task list/detail views
- ✅ Knowledge graph browser
- ✅ Settings with connection config
- ✅ Dark theme

## What Nerve Has (Reference: `~/projects/openclaw-nerve/src/features/`)

| Nerve Feature | Priority | Status in Fork |
|---|---|---|
| Chat (multi-session, streaming) | P0 | Partial — needs session switching, streaming tokens |
| Sessions (list, switch, create) | P0 | Missing |
| Cron management (list, create, edit, run, toggle) | P0 | Missing |
| Memory browser (MEMORY.md, daily files) | P1 | Missing |
| Dashboard/Status (agent status, model, uptime) | P1 | Partial — basic status exists |
| Kanban board | P1 | Partial — has tasks but not kanban-style |
| Notifications | P2 | Missing |
| File browser | P2 | Missing |
| Voice/TTS | P2 | Missing |
| Workspace explorer | P3 | Missing |
| Command palette | P3 | Missing |

## Architecture

```
┌──────────────────────────────────────────┐
│            OpenClaw Mobile               │
│                                          │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │  Chat   │ │Sessions │ │  Crons  │   │
│  └────┬────┘ └────┬────┘ └────┬────┘   │
│       │           │           │          │
│  ┌────▼───────────▼───────────▼────┐    │
│  │       GatewayService            │    │
│  │   (WebSocket + socket.io)       │    │
│  └─────────────┬───────────────────┘    │
│                │                         │
│  ┌─────────────▼───────────────────┐    │
│  │       WidgetKit Extensions      │    │
│  │  • Status Widget (small/medium) │    │
│  │  • Last Message Widget          │    │
│  │  • Active Tasks Widget          │    │
│  └─────────────────────────────────┘    │
└──────────────────────────────────────────┘
            │
            ▼ WSS (socket.io)
    ┌───────────────┐
    │ OpenClaw      │
    │ Gateway       │
    │ (:18789)      │
    └───────────────┘
```

## Phase 1: Core Features (Chat + Sessions + Crons)

### 1.1 Fix/Enhance Chat
- [ ] Multi-session support (session picker, create new, switch)
- [ ] Streaming token display (not wait for full response)
- [ ] Markdown rendering in messages (code blocks, links, bold/italic)
- [ ] Copy message content
- [ ] Pull-to-refresh history
- [ ] Session search

### 1.2 Sessions Management
- [ ] List all sessions (active, recent)
- [ ] Switch between sessions
- [ ] Create new session
- [ ] Session metadata (model, last message, created date)
- [ ] Delete/archive session

### 1.3 Cron Management
- [ ] List all cron jobs (name, schedule, status, last run)
- [ ] Toggle enable/disable
- [ ] Trigger manual run
- [ ] Create new cron job
- [ ] Edit existing cron
- [ ] View run history
- [ ] Display next run time

## Phase 2: Memory + Status + Kanban

### 2.1 Memory Browser
- [ ] View MEMORY.md
- [ ] List daily memory files (memory/YYYY-MM-DD.md)
- [ ] Read file content with markdown rendering
- [ ] Search across memory files

### 2.2 Status Dashboard
- [ ] Agent status (name, model, uptime)
- [ ] Gateway version
- [ ] Connected channels
- [ ] Active sessions count
- [ ] Recent activity feed

### 2.3 Kanban Board
- [ ] Kanban columns (backlog, todo, in-progress, review, done)
- [ ] Drag-and-drop (or tap-to-move) between columns
- [ ] Create/edit tasks
- [ ] Priority badges
- [ ] Assignee display

## Phase 3: Widgets (WidgetKit)

### 3.1 Status Widget (Small)
- Agent connection status (green/red dot)
- Agent name
- Last activity timestamp

### 3.2 Last Message Widget (Medium)
- Most recent message from agent
- Session name
- Tap to open that session

### 3.3 Active Tasks Widget (Medium)
- Count of tasks by status
- Top 3 in-progress tasks
- Tap to open kanban

### Widget Architecture
- Shared App Group for data persistence between app and widget
- Background refresh via `TimelineProvider`
- Gateway polling for fresh data (lightweight REST calls, not WebSocket)
- Widgets use the REST API endpoints, not the socket.io connection

## Phase 4: Polish + Extras

- [ ] Notifications (push via APNs or local)
- [ ] File browser (workspace files)
- [ ] Voice input / TTS playback
- [ ] iPad layout (sidebar + detail)
- [ ] Haptic feedback
- [ ] App icon + launch screen

## Technical Decisions

### Package Structure
Convert from SPM library to proper Xcode app project:
- Main app target
- Widget extension target
- Shared framework (models, services, theme)

### Auth
- Token-based auth via socket.io handshake (already implemented)
- Token stored in Keychain (not @AppStorage)
- Shared Keychain group for widget access

### State Management
- `@Observable` (iOS 17+) for services
- `SwiftData` for local message cache
- `@AppStorage` for simple prefs
- Keychain for secrets

### Networking
- URLSessionWebSocketTask for gateway (existing)
- Gateway socket.io protocol (existing, needs cleanup)
- REST fallback for widgets (lightweight status/history endpoints)

### Target
- iOS 17+ (drop the iOS 18 requirement for wider compatibility)
- Swift 6
- Zero third-party dependencies

## Files to Modify/Create

### Modify
- `Package.swift` → Convert to Xcode project with app + widget targets
- `GatewayService.swift` → Add session management, cron API, streaming
- `Configuration.swift` → Keychain storage, app group for widgets
- `ContentView.swift` → New tab layout (Chat, Sessions, Crons, More)
- `ChatView.swift` → Multi-session, streaming, markdown
- `AppTheme.swift` → Refine colors, add Nerve-inspired styling

### Create (Phase 1)
- `Services/SessionService.swift` — Session CRUD via gateway
- `Services/CronService.swift` — Cron CRUD via gateway
- `Models/Session.swift` — Session data model
- `Models/CronJob.swift` — Cron job data model
- `Views/Sessions/SessionsView.swift` — Session list
- `Views/Sessions/SessionRow.swift` — Session list item
- `Views/Crons/CronsView.swift` — Cron job list
- `Views/Crons/CronRow.swift` — Cron list item
- `Views/Crons/CronDetailView.swift` — Cron detail/edit
- `Views/Crons/CreateCronView.swift` — New cron form

### Create (Phase 2)
- `Services/MemoryService.swift` — Memory file access
- `Views/Memory/MemoryBrowserView.swift`
- `Views/Memory/MemoryFileView.swift`
- `Views/Status/StatusDashboardView.swift`
- `Views/Kanban/KanbanBoardView.swift`
- `Views/Kanban/KanbanColumnView.swift`
- `Views/Kanban/TaskCardView.swift`

### Create (Phase 3 — Widget Extension)
- `Widget/OpenClawWidgets.swift` — Widget bundle
- `Widget/StatusWidget.swift`
- `Widget/LastMessageWidget.swift`
- `Widget/ActiveTasksWidget.swift`
- `Widget/WidgetDataProvider.swift` — Shared data fetcher

## Gateway Socket.IO Events (Reference)

Based on Nerve source (`~/projects/openclaw-nerve/src/`):

### Chat
- `chat.send` → Send message to session
- `chat.history` → Get message history
- `chat.stream` → Streaming token events

### Sessions
- `sessions.list` → List all sessions
- `sessions.create` → Create new session
- `sessions.delete` → Delete session
- `sessions.preview` → Get session preview/metadata

### Crons
- `crons.list` → List all cron jobs
- `crons.add` → Create cron job
- `crons.update` → Update cron job
- `crons.remove` → Delete cron job
- `crons.run` → Trigger manual run
- `crons.runs` → Get run history

### Status
- `status` → Gateway status
- `gateway.identity.get` → Gateway identity info

### Memory/Files
- `workspace.read` → Read file from workspace
- `workspace.list` → List workspace files
