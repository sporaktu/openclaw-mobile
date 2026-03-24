import SwiftUI

struct ChatContainerView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(AppConfiguration.self) private var config

    @State private var messageText = ""
    @State private var showNewSessionAlert = false
    @State private var newSessionLabel = ""

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Connection banner
                if !gateway.isConnected && config.isConfigured {
                    connectionBanner
                }

                // Session picker
                sessionPicker

                Divider()
                    .background(AppTheme.textTertiary.opacity(0.3))

                // Chat content
                ChatView()
                    .environment(gateway)
                    .environment(config)

                Divider()
                    .background(AppTheme.textTertiary.opacity(0.3))

                // Input bar
                ChatInputBar(text: $messageText, isLoading: gateway.isGenerating) {
                    await sendMessage()
                }
            }
        }
        .alert("New Session", isPresented: $showNewSessionAlert) {
            TextField("Session label", text: $newSessionLabel)
            Button("Create") {
                Task {
                    let key = newSessionLabel.isEmpty
                        ? "session-\(Int(Date().timeIntervalSince1970))"
                        : newSessionLabel.lowercased().replacingOccurrences(of: " ", with: "-")
                    await gateway.switchSession(to: key)
                    newSessionLabel = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newSessionLabel = ""
            }
        } message: {
            Text("Enter a label for the new session.")
        }
    }

    // MARK: - Session Picker

    private var sessionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(gateway.sessions) { session in
                    sessionPill(session)
                }

                Button {
                    showNewSessionAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppTheme.background)
    }

    private func sessionPill(_ session: Session) -> some View {
        Button {
            Task {
                await gateway.switchSession(to: session.sessionKey)
            }
        } label: {
            HStack(spacing: 6) {
                if session.isActive {
                    Circle()
                        .fill(AppTheme.statusInProgress)
                        .frame(width: 6, height: 6)
                }
                Text(session.effectiveLabel)
                    .font(AppTheme.captionFont)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                session.sessionKey == gateway.currentSessionKey
                    ? AppTheme.accent
                    : AppTheme.cardBackground
            )
            .foregroundStyle(
                session.sessionKey == gateway.currentSessionKey
                    ? Color.white
                    : AppTheme.textSecondary
            )
            .clipShape(Capsule())
        }
    }

    // MARK: - Connection Banner

    private var connectionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12))
            Text("Disconnected")
                .font(AppTheme.captionFont)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.8))
    }

    // MARK: - Actions

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        await gateway.sendMessage(text, sessionKey: gateway.currentSessionKey)
    }
}

#Preview {
    ChatContainerView()
        .environment(GatewayService())
        .environment(AppConfiguration())
}
