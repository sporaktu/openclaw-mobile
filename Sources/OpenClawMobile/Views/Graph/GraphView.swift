import SwiftUI

struct GraphView: View {
    @Environment(AppConfiguration.self) private var config
    @Environment(KnowledgeGraphService.self) private var kgService
    @State private var entities: [Entity] = []
    @State private var searchText = ""
    @State private var selectedFilter: EntityTypeFilter = .all
    @State private var isLoading = false
    @State private var error: String?

    var filteredEntities: [Entity] {
        var result = entities

        if selectedFilter != .all, let apiValue = selectedFilter.apiValue {
            result = result.filter { $0.type.lowercased() == apiValue }
        }

        if !searchText.isEmpty {
            result = result.filter { entity in
                entity.name.localizedCaseInsensitiveContains(searchText) ||
                (entity.summary ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Picker
                    Picker("Type", selection: $selectedFilter) {
                        ForEach(EntityTypeFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if !kgService.isConfigured {
                        unconfiguredView
                    } else if isLoading && entities.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(AppTheme.accent)
                        Spacer()
                    } else if filteredEntities.isEmpty {
                        emptyStateView
                    } else {
                        entityList
                    }
                }
            }
            .navigationTitle("Knowledge Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search entities...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadEntities() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .task {
                await loadEntities()
            }
        }
    }

    // MARK: - Entity List

    private var entityList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredEntities) { entity in
                    NavigationLink(destination: EntityDetailView(entity: entity)) {
                        EntityRow(entity: entity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await loadEntities()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "circle.grid.cross")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)
            Text("No entities found")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Entities from your knowledge graph\nwill appear here")
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

    private func loadEntities() async {
        guard kgService.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }

        await kgService.fetchEntities(type: selectedFilter.apiValue)
        entities = kgService.entities
        error = kgService.error
    }
}

#Preview {
    GraphView()
        .environment(AppConfiguration())
        .environment(KnowledgeGraphService())
}
