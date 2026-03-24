import SwiftUI

struct TasksView: View {
    @Environment(KnowledgeGraphService.self) private var kgService
    @State private var tasks: [AgentTask] = []
    @State private var selectedFilter: TaskFilter = .all
    @State private var isLoading = false
    @State private var error: String?

    var filteredTasks: [AgentTask] {
        switch selectedFilter {
        case .all:
            return tasks
        case .inProgress:
            return tasks.filter { $0.status.lowercased() == "in_progress" }
        case .pending:
            return tasks.filter { $0.status.lowercased() == "pending" }
        case .completed:
            return tasks.filter { $0.status.lowercased() == "completed" }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(TaskFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if !kgService.isConfigured {
                        unconfiguredView
                    } else if isLoading && tasks.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(AppTheme.accent)
                        Spacer()
                    } else if filteredTasks.isEmpty {
                        emptyStateView
                    } else {
                        taskList
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadTasks() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .task {
                await loadTasks()
            }
            .onChange(of: selectedFilter) { _, _ in
                Task { await loadTasks() }
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await loadTasks()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No tasks found")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Tasks from your knowledge graph will appear here")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Unconfigured

    private var unconfiguredView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "gear.badge.xmark")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Knowledge Graph Not Configured")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Go to Settings to enter your\nKnowledge Graph API URL.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Data Loading

    private func loadTasks() async {
        guard kgService.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }

        await kgService.fetchTasks(status: selectedFilter.apiValue)
        tasks = kgService.tasks
        error = kgService.error
    }
}

#Preview {
    TasksView()
        .environment(KnowledgeGraphService())
}
