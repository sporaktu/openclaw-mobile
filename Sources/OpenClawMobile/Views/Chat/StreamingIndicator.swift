import SwiftUI

struct StreamingIndicator: View {
    let stage: ProcessingStage?
    let streamingText: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                switch stage {
                case .thinking:
                    thinkingView
                case .streaming:
                    streamingView
                case .toolUse:
                    toolUseView
                case nil:
                    thinkingView
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.assistantBubble)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 60)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Thinking (bouncing dots)

    private var thinkingView: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                BouncingDot(delay: Double(index) * 0.15)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Streaming text preview

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(streamingText)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 4) {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 6, height: 6)
                    .opacity(0.8)
                    .modifier(PulseModifier())
                Text("Streaming...")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }

    // MARK: - Tool use

    private var toolUseView: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.accent)
                .rotationEffect(.degrees(toolRotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        toolRotation = 360
                    }
                }
            Text("Using tool...")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    @State private var toolRotation: Double = 0
}

// MARK: - Bouncing Dot

private struct BouncingDot: View {
    let delay: Double
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(AppTheme.textSecondary)
            .frame(width: 8, height: 8)
            .offset(y: animating ? -6 : 0)
            .animation(
                .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

#Preview {
    VStack(spacing: 16) {
        StreamingIndicator(stage: .thinking, streamingText: "")
        StreamingIndicator(stage: .streaming, streamingText: "The answer to your question is that Swift provides powerful concurrency features...")
        StreamingIndicator(stage: .toolUse, streamingText: "")
    }
    .padding()
    .background(AppTheme.background)
}
