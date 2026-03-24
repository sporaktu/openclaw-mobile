import SwiftUI

struct ChatView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(AppConfiguration.self) private var config

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if !config.isConfigured {
                unconfiguredView
            } else {
                chatContent
            }
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = gateway.error {
                errorBanner(error)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if gateway.messages.isEmpty && !gateway.isGenerating {
                            emptyStateView
                        }

                        ForEach(gateway.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if gateway.isGenerating {
                            StreamingIndicator(
                                stage: gateway.processingStage,
                                streamingText: gateway.streamingText
                            )
                            .id("streaming")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .refreshable {
                    await gateway.fetchHistory(sessionKey: gateway.currentSessionKey)
                }
                .onChange(of: gateway.messages.count) { _, _ in
                    withAnimation {
                        if gateway.isGenerating {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        } else if let lastId = gateway.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: gateway.streamingText) { _, _ in
                    if gateway.isGenerating {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text(message)
                .font(AppTheme.captionFont)
                .lineLimit(2)
            Spacer()
            Button {
                gateway.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.statusBlocked.opacity(0.85))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 100)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No messages yet")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Start a conversation with your OpenClaw agent")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Unconfigured View

    private var unconfiguredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.xmark")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Gateway Not Configured")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Go to Settings to enter your\nOpenClaw Gateway URL and token.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ChatView()
        .environment(GatewayService())
        .environment(AppConfiguration())
}
