import SwiftUI

struct SessionDetailView: View {
    @Environment(GatewayService.self) private var gateway
    @Environment(\.dismiss) private var dismiss

    let session: Session

    @State private var editedLabel: String = ""
    @State private var selectedThinking: String = "off"
    @State private var showResetAlert = false
    @State private var showDeleteAlert = false
    @State private var isSaving = false

    private let thinkingLevels = ["off", "low", "medium", "high"]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.spacing) {
                    labelSection
                    modelSection
                    thinkingSection
                    tokenSection
                    actionsSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await saveChanges() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(AppTheme.accent)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            editedLabel = session.label ?? ""
            selectedThinking = session.thinking ?? "off"
        }
        .alert("Reset Session?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await gateway.resetSession(key: session.sessionKey)
                    dismiss()
                }
            }
        } message: {
            Text("This will clear all messages in this session. This cannot be undone.")
        }
        .alert("Delete Session?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await gateway.deleteSession(key: session.sessionKey)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete this session and all its messages.")
        }
    }

    // MARK: - Sections

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Label")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            TextField("Session label", text: $editedLabel)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
                .textFieldStyle(.roundedBorder)
        }
        .cardStyle()
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            Text(session.model ?? "Default")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var thinkingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thinking Level")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            Picker("Thinking", selection: $selectedThinking) {
                ForEach(thinkingLevels, id: \.self) { level in
                    Text(level.capitalized).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
        .cardStyle()
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token Usage")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 24) {
                tokenStat(label: "Total", value: session.totalTokens)
                tokenStat(label: "Context", value: session.contextTokens)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func tokenStat(label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            Text(value.map { formatTokens($0) } ?? "--")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await gateway.switchSession(to: session.sessionKey)
                    NotificationCenter.default.post(
                        name: .switchToChat, object: nil
                    )
                    dismiss()
                }
            } label: {
                Label("Switch to Session", systemImage: "arrow.right.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }

            Button {
                showResetAlert = true
            } label: {
                Label("Reset Session", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.orange)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }

            Button {
                showDeleteAlert = true
            } label: {
                Label("Delete Session", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        let label = editedLabel.isEmpty ? nil : editedLabel
        let thinking = selectedThinking

        await gateway.patchSession(
            key: session.sessionKey,
            label: label,
            thinking: thinking
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
    NavigationStack {
        SessionDetailView(
            session: Session(
                sessionKey: "abc-123",
                label: "Main Chat",
                state: "idle",
                agentState: nil,
                busy: false,
                lastActivity: nil,
                updatedAt: Date().timeIntervalSince1970 * 1000,
                model: "claude-sonnet-4-20250514",
                thinking: "medium",
                totalTokens: 45_200,
                contextTokens: 12_000,
                channel: nil,
                kind: nil,
                displayName: nil,
                parentId: nil
            )
        )
    }
    .environment(GatewayService())
}
