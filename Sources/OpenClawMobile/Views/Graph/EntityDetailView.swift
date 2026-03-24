import SwiftUI

struct EntityDetailView: View {
    let entity: Entity
    @Environment(KnowledgeGraphService.self) private var kgService
    @State private var fullEntity: Entity?
    @State private var relationships: [Relationship] = []
    @State private var isLoading = false

    private var displayEntity: Entity {
        fullEntity ?? entity
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    headerSection

                    // Summary
                    if let summary = displayEntity.summary, !summary.isEmpty {
                        summarySection(summary)
                    }

                    // Facts
                    if let facts = displayEntity.facts, !facts.isEmpty {
                        factsSection(facts)
                    }

                    // Relationships
                    if !relationships.isEmpty {
                        relationshipsSection
                    }

                    // Events
                    if let events = displayEntity.events, !events.isEmpty {
                        eventsSection(events)
                    }

                    // Tasks
                    if let tasks = displayEntity.tasks, !tasks.isEmpty {
                        tasksSection(tasks)
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(AppTheme.accent)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadDetails()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: entity.typeIcon)
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 56, height: 56)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.name)
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(entity.type.capitalized)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(Capsule())

                if let aliases = entity.aliases, !aliases.isEmpty {
                    Text("aka \(aliases)")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Summary

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Summary")
            Text(summary)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Facts

    private func factsSection(_ facts: [Fact]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Facts (\(facts.count))")

            ForEach(facts) { fact in
                HStack(alignment: .top, spacing: 8) {
                    Text(fact.key)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 100, alignment: .trailing)

                    Text(fact.value)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)

                if fact.id != facts.last?.id {
                    Divider()
                        .background(AppTheme.textTertiary.opacity(0.3))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Relationships

    private var relationshipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Relationships (\(relationships.count))")

            FlowLayout(spacing: 8) {
                ForEach(relationships) { rel in
                    let targetName = rel.targetEntity ?? rel.sourceEntity ?? "Entity #\(rel.targetEntityId ?? 0)"
                    VStack(spacing: 2) {
                        Text(targetName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text(rel.relationType.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Events

    private func eventsSection(_ events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Events (\(events.count))")

            ForEach(events) { event in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(event.description)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                        if let date = event.date {
                            Text(date)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle()
    }

    // MARK: - Tasks

    private func tasksSection(_ tasks: [AgentTask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Tasks (\(tasks.count))")

            ForEach(tasks) { task in
                HStack(spacing: 8) {
                    Text(task.statusIcon)
                    Text(task.name)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    if let priority = task.priority {
                        StatusBadge(text: priority.capitalized, color: AppTheme.textTertiary)
                    }
                }
                .padding(.vertical, 4)
            }
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

    private func loadDetails() async {
        guard kgService.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }

        if let detail = await kgService.fetchEntity(name: entity.name) {
            fullEntity = detail
        }
        relationships = await kgService.fetchRelationships(entity: entity.name)
    }
}

#Preview {
    NavigationStack {
        EntityDetailView(entity: Entity(
            id: 1,
            type: "person",
            name: "Alice",
            aliases: "alice_dev",
            summary: "Creator of an open-source AI agent platform.",
            metadata: nil,
            createdAt: nil,
            updatedAt: nil,
            facts: [
                Fact(id: 1, entityId: 1, key: "role", value: "Developer", confidence: 0.95, source: nil, createdAt: nil),
                Fact(id: 2, entityId: 1, key: "location", value: "San Francisco, CA", confidence: nil, source: nil, createdAt: nil)
            ],
            relationships: nil,
            events: [
                Event(id: 1, entityId: 1, eventType: "project_start", description: "Started OpenClaw development", date: "2024-06-01", source: nil, createdAt: nil)
            ],
            tasks: [
                AgentTask(id: 1, name: "Ship v1.0", description: nil, status: "in_progress", priority: "high", assignedTo: nil, linkedEntities: nil, parentTaskId: nil, createdAt: nil, updatedAt: nil, completedAt: nil)
            ]
        ))
    }
    .environment(KnowledgeGraphService())
}
