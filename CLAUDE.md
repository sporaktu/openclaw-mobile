# CLAUDE.md — Agent Instructions

## Project

OpenClaw Mobile — Native iOS app + widgets that mirrors the Nerve web dashboard.
Forked from `abhione/openclaw-mobile`. See `PLAN.md` for full feature plan.

## Architecture

- **SwiftUI** — declarative UI, iOS 17+
- **Swift 6** — strict concurrency
- **Zero third-party deps** — URLSession, CryptoKit, SwiftData, WidgetKit only
- **WebSocket** — socket.io protocol to OpenClaw gateway
- **WidgetKit** — home screen widgets via App Group shared data

## Source Layout

```
Sources/OpenClawMobile/
├── App/          → Entry point, tab navigation
├── Models/       → Codable data models
├── Services/     → API clients (GatewayService, etc.)
├── Views/        → SwiftUI views by feature
│   ├── Chat/
│   ├── Sessions/
│   ├── Crons/
│   ├── Memory/
│   ├── Kanban/
│   ├── Status/
│   ├── Settings/
│   └── Components/
└── Theme/        → Colors, fonts, styling
Widget/           → WidgetKit extension
Shared/           → Models and services shared between app + widget
```

## Standards

- **SDD (Software Design Document)**: Produce a design document before implementing. Include: component diagrams, data models, API contracts, state management approach, error handling strategy.
- **Plan mode first**: Research best practices, then design, then implement.
- **Sub-agents for implementation**: Use focused sub-agents per feature area.
- Follow Swift naming conventions and SwiftUI best practices.
- Use `async/await` for all async work.
- Keep views small and composable.
- `@Observable` for services (iOS 17+).
- Keychain for secrets, `@AppStorage` for prefs only.
- Every view should have a `#Preview`.

## Gateway Protocol (socket.io)

The gateway uses socket.io over WebSocket. Protocol:
- Connect: `40{"auth":{"token":"..."}}`
- Ping/Pong: `2` / `3`
- Events: `42["eventName", {payload}]`

Key events:
- `chat.send`, `chat.history`, `chat.stream`
- `sessions.list`, `sessions.create`, `sessions.delete`
- `crons.list`, `crons.add`, `crons.update`, `crons.remove`, `crons.run`
- `status`, `gateway.identity.get`
- `workspace.read`, `workspace.list`

## Current State

The fork has basic chat, task list, and graph browser working.
GatewayService.swift has a working WebSocket + socket.io implementation.
We need to add: multi-session chat, session management, cron management,
memory browser, status dashboard, kanban, and WidgetKit widgets.

## Build

This is an SPM package. Needs conversion to Xcode app project.
```bash
# Open in Xcode
open Package.swift
# Or generate .xcodeproj
swift package generate-xcodeproj
```

## Reference App

Nerve web dashboard source is at `~/projects/openclaw-nerve/src/` for
reference on features, layouts, and gateway API usage.
