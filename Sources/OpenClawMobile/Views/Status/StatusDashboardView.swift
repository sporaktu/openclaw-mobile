import SwiftUI

struct StatusDashboardView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(KanbanService.self) private var kanbanService
    @State private var statusData: StatusInfo?
    @State private var recentEvents: [ActivityEvent] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing) {
                    connectionCard
                    agentInfoCard
                    statsCard
                    activityCard
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Dashboard")
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
        }
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(gateway.isConnected ? AppTheme.statusCompleted : AppTheme.statusBlocked)
                .frame(width: 14, height: 14)
                .shadow(color: gateway.isConnected ? AppTheme.statusCompleted.opacity(0.5) : .clear, radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(gateway.isConnected ? "Connected" : "Disconnected")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)

                if let status = statusData {
                    Text("Gateway v\(status.version)")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            Spacer()

            if !gateway.isConnected {
                Button("Reconnect") {
                    Task {
                        try? await gateway.connect()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.small)
            }
        }
        .cardStyle()
    }

    // MARK: - Agent Info Card

    private var agentInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Agent", systemImage: "cpu")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusData?.agentName ?? gateway.agentName)
                        .font(AppTheme.headlineFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    if let model = statusData?.model {
                        Text(model)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if let uptime = statusData?.uptime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Uptime")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(uptime)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(
                title: "Sessions",
                value: "\(gateway.sessions.count)",
                icon: "rectangle.stack",
                color: AppTheme.accent
            )

            Divider()
                .frame(height: 40)
                .background(AppTheme.textTertiary.opacity(0.3))

            statItem(
                title: "Active",
                value: "\(gateway.sessions.filter(\.isActive).count)",
                icon: "bolt.fill",
                color: AppTheme.statusCompleted
            )

            Divider()
                .frame(height: 40)
                .background(AppTheme.textTertiary.opacity(0.3))

            statItem(
                title: "Tasks",
                value: "\(kanbanService.tasks.count)",
                icon: "checklist",
                color: AppTheme.statusPending
            )

            Divider()
                .frame(height: 40)
                .background(AppTheme.textTertiary.opacity(0.3))

            statItem(
                title: "In Progress",
                value: "\(kanbanService.inProgressTasks.count)",
                icon: "play.circle",
                color: AppTheme.statusInProgress
            )
        }
        .cardStyle()
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(title)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recent Activity", systemImage: "clock")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)

            if recentEvents.isEmpty {
                Text("No recent activity")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentEvents) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(event.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.description)
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            Text(event.timeAgo)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textTertiary)
                        }

                        Spacer()
                    }

                    if event.id != recentEvents.last?.id {
                        Divider()
                            .background(AppTheme.textTertiary.opacity(0.2))
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Refresh

    private func refresh() async {
        await gateway.fetchStatus()
        await gateway.listSessions()

        // Build status info from gateway data
        do {
            let result = try await gateway.rpc("status", params: [:])
            statusData = StatusInfo.from(dict: result)
        } catch {
            // Non-critical
        }

        // Build recent activity from sessions
        recentEvents = gateway.sessions
            .sorted { ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0) }
            .prefix(10)
            .compactMap { session -> ActivityEvent? in
                ActivityEvent(
                    id: session.sessionKey,
                    description: session.isActive
                        ? "\(session.effectiveLabel) is active"
                        : "Session: \(session.effectiveLabel)",
                    icon: session.isActive ? "bolt.fill" : "bubble.left",
                    color: session.isActive ? AppTheme.statusCompleted : AppTheme.accent,
                    date: session.lastActivityDate
                )
            }
    }
}

// MARK: - Supporting Types

private struct StatusInfo {
    let agentName: String
    let model: String
    let version: String
    let uptime: String
    let channels: [String]

    static func from(dict: [String: Any]) -> StatusInfo? {
        let h = dict["h"] as? [String: Any]
        let agent = h?["agent"] as? [String: Any]
        let gateway = h?["gateway"] as? [String: Any]

        let agentName = agent?["name"] as? String ?? "Unknown"
        let model = agent?["model"] as? String ?? ""
        let version = gateway?["version"] as? String ?? dict["version"] as? String ?? "?"

        var uptime = "—"
        if let startedAt = gateway?["startedAt"] as? Double {
            let started = Date(timeIntervalSince1970: startedAt / 1000)
            let interval = Date().timeIntervalSince(started)
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            if hours > 24 {
                uptime = "\(hours / 24)d \(hours % 24)h"
            } else if hours > 0 {
                uptime = "\(hours)h \(minutes)m"
            } else {
                uptime = "\(minutes)m"
            }
        }

        let channels = (h?["channels"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []

        return StatusInfo(agentName: agentName, model: model, version: version, uptime: uptime, channels: channels)
    }
}

private struct ActivityEvent: Identifiable {
    let id: String
    let description: String
    let icon: String
    let color: Color
    let date: Date?

    var timeAgo: String {
        guard let date else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

#Preview {
    StatusDashboardView()
        .environment(GatewayService())
        .environment(KanbanService())
        .preferredColorScheme(.dark)
}
