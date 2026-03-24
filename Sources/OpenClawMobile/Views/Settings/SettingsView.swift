import SwiftUI

struct SettingsView: View {
    @Environment(AppConfiguration.self) private var config
    @Environment(GatewayService.self) private var gateway
    @Environment(KnowledgeGraphService.self) private var kgService
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var gatewayStatus: GatewayStatus?
    @State private var kgStats: KGStats?

    // Local editing copies (Keychain token can't be bound directly)
    @State private var editingToken = ""
    @State private var tokenLoaded = false

    var body: some View {
        @Bindable var config = config

        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        gatewaySection
                        knowledgeGraphSection
                        testSection

                        if gateway.isConnected {
                            agentInfoSection
                        }

                        if let stats = kgStats {
                            kgStatsSection(stats)
                        }

                        appInfoSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if !tokenLoaded {
                editingToken = config.gatewayToken
                tokenLoaded = true
            }
        }
    }

    // MARK: - Gateway Section

    private var gatewaySection: some View {
        @Bindable var config = config

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("OpenClaw Gateway")
                Spacer()
                ConnectionIndicator(isConnected: gateway.isConnected)
            }

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 20)
                    TextField("Gateway URL", text: $config.gatewayURL)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Divider()
                    .background(AppTheme.textTertiary.opacity(0.3))

                HStack {
                    Image(systemName: "key")
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 20)
                    SecureField("Gateway Token", text: $editingToken)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: editingToken) { _, newValue in
                            config.gatewayToken = newValue
                        }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Knowledge Graph Section

    private var knowledgeGraphSection: some View {
        @Bindable var config = config

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Knowledge Graph API")
                Spacer()
                ConnectionIndicator(isConnected: kgStats != nil)
            }

            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 20)
                    TextField("KG API URL", text: $config.kgAPIURL)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Divider()
                    .background(AppTheme.textTertiary.opacity(0.3))

                HStack {
                    Image(systemName: "key")
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 20)
                    SecureField("KG API Token", text: $config.kgAPIToken)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await testConnections() }
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    Text("Test Connections")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .disabled(isTesting)

            if let result = testResult {
                Text(result)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Agent Info

    private var agentInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Agent Info")

            if !gateway.agentName.isEmpty {
                infoRow(label: "Model", value: gateway.agentName)
            }

            if let status = gatewayStatus {
                if let version = status.version {
                    infoRow(label: "Version", value: version)
                }
                if let uptime = status.uptime {
                    infoRow(label: "Uptime", value: uptime)
                }
            }

            infoRow(label: "Sessions", value: "\(gateway.sessions.count)")
        }
        .cardStyle()
    }

    // MARK: - KG Stats

    private func kgStatsSection(_ stats: KGStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Knowledge Graph Stats")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(label: "Entities", value: stats.entityCount ?? 0)
                statCard(label: "Facts", value: stats.factCount ?? 0)
                statCard(label: "Relations", value: stats.relationshipCount ?? 0)
                statCard(label: "Events", value: stats.eventCount ?? 0)
                statCard(label: "Tasks", value: stats.taskCount ?? 0)
            }
        }
        .cardStyle()
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("About")

            HStack {
                Text("OpenClaw Mobile")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("v1.0.0")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Text("Companion app for OpenClaw — the open-source AI agent platform.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.captionFont)
            .foregroundStyle(AppTheme.textTertiary)
            .textCase(.uppercase)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func statCard(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
    }

    // MARK: - Actions

    private func testConnections() async {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        var results: [String] = []

        // Test Gateway
        if config.isConfigured {
            do {
                let url = URL(string: config.normalizedGatewayURL + "/api/status")!
                var req = URLRequest(url: url)
                req.setValue("Bearer \(config.gatewayToken)", forHTTPHeaderField: "Authorization")
                let (data, _) = try await URLSession.shared.data(for: req)
                let status = try JSONDecoder().decode(GatewayStatus.self, from: data)
                gatewayStatus = status
                results.append("Gateway connected")
            } catch {
                results.append("Gateway failed: \(error.localizedDescription)")
            }
        } else {
            results.append("Gateway not configured")
        }

        // Test KG
        if kgService.isConfigured {
            if let stats = await kgService.fetchStats() {
                kgStats = stats
                results.append("KG connected (\(stats.entityCount ?? 0) entities)")
            } else {
                results.append("KG connection failed")
            }
        } else {
            results.append("KG not configured")
        }

        testResult = results.joined(separator: "\n")
    }
}

#Preview {
    SettingsView()
        .environment(AppConfiguration())
        .environment(GatewayService())
        .environment(KnowledgeGraphService())
}
