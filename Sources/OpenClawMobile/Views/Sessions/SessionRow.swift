import SwiftUI

struct SessionRow: View {
    let session: Session
    let isCurrentSession: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Activity indicator dot
            Circle()
                .fill(session.isActive ? Color.green : AppTheme.textTertiary)
                .frame(width: 8, height: 8)

            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.effectiveLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if let model = session.model, !model.isEmpty {
                    Text(model)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                if let date = session.lastActivityDate {
                    Text(date, style: .relative)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }

            Spacer()

            // Token count badge
            if let tokens = session.totalTokens, tokens > 0 {
                Text(formatTokens(tokens))
                    .font(AppTheme.badgeFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.cardBackground)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(isCurrentSession ? AppTheme.accent : .clear, lineWidth: 2)
        )
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

#Preview {
    VStack(spacing: 8) {
        SessionRow(
            session: Session(
                sessionKey: "abc-123",
                label: "Main Chat",
                state: "thinking",
                agentState: nil,
                busy: true,
                lastActivity: nil,
                updatedAt: Date().timeIntervalSince1970 * 1000 - 120_000,
                model: "claude-sonnet-4-20250514",
                thinking: "medium",
                totalTokens: 45_200,
                contextTokens: 12_000,
                channel: nil,
                kind: nil,
                displayName: nil,
                parentId: nil
            ),
            isCurrentSession: true
        )
        SessionRow(
            session: Session(
                sessionKey: "def-456",
                label: nil,
                state: "idle",
                agentState: nil,
                busy: false,
                lastActivity: nil,
                updatedAt: Date().timeIntervalSince1970 * 1000 - 3_600_000,
                model: "claude-sonnet-4-20250514",
                thinking: nil,
                totalTokens: nil,
                contextTokens: nil,
                channel: nil,
                kind: nil,
                displayName: "Research Agent",
                parentId: nil
            ),
            isCurrentSession: false
        )
    }
    .padding()
    .background(AppTheme.background)
}
