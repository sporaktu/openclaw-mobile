import SwiftUI

struct SessionsListView: View {
    @Environment(GatewayService.self) private var gateway
    @State private var searchText = ""
    @State private var showSubAgents = false
    @State private var showCreateSheet = false
    @State private var newSessionLabel = ""
    @State private var isLoading = false

    private var filteredSessions: [Session] {
        var result = gateway.sessions
        if !showSubAgents {
            result = result.filter { !$0.isSubAgent }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.effectiveLabel.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if isLoading && gateway.sessions.isEmpty {
                    ProgressView()
                        .tint(AppTheme.accent)
                } else if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newSessionLabel = ""
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $showSubAgents) {
                        Image(systemName: "person.2")
                    }
                    .toggleStyle(.button)
                    .tint(showSubAgents ? AppTheme.accent : AppTheme.textTertiary)
                }
            }
            .task {
                isLoading = true
                await gateway.listSessions()
                isLoading = false
            }
            .sheet(isPresented: $showCreateSheet) {
                createSessionSheet
            }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRow(
                            session: session,
                            isCurrentSession: session.sessionKey == gateway.currentSessionKey
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            Task { await gateway.switchSession(to: session.sessionKey) }
                            NotificationCenter.default.post(
                                name: .switchToChat, object: nil
                            )
                        } label: {
                            Label("Switch to Session", systemImage: "arrow.right.circle")
                        }
                        Button(role: .destructive) {
                            Task { await gateway.deleteSession(key: session.sessionKey) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await gateway.listSessions()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No sessions found")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Create a new session to get started")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
        }
        .padding()
    }

    // MARK: - Create Session Sheet

    private var createSessionSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: AppTheme.spacing) {
                    TextField("Session label (optional)", text: $newSessionLabel)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                Spacer()
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let label = newSessionLabel.isEmpty ? nil : newSessionLabel
                            _ = await gateway.createSession(label: label)
                            showCreateSheet = false
                            await gateway.listSessions()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Notification

extension Notification.Name {
    static let switchToChat = Notification.Name("switchToChat")
}

#Preview {
    SessionsListView()
        .environment(GatewayService())
}
