import SwiftUI

struct TaskDetailView: View {
    let task: AgentTask
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    headerSection

                    // Description
                    if let description = task.description, !description.isEmpty {
                        descriptionSection(description)
                    }

                    // Details
                    detailsSection

                    // Linked Entities
                    if let entities = task.linkedEntities, !entities.isEmpty {
                        linkedEntitiesSection(entities)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.statusIcon)
                    .font(.system(size: 32))
                Text(task.name)
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            HStack(spacing: 8) {
                StatusBadge(
                    text: task.status.replacingOccurrences(of: "_", with: " ").capitalized,
                    color: statusColor
                )

                if let priority = task.priority {
                    StatusBadge(
                        text: priority.capitalized,
                        color: priorityColor(priority)
                    )
                }
            }
        }
    }

    // MARK: - Description

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Description")
            Text(description)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Details")

            if let assignedTo = task.assignedTo {
                detailRow(icon: "person.fill", label: "Assigned To", value: assignedTo)
            }

            if let createdAt = task.createdAt {
                detailRow(icon: "calendar", label: "Created", value: formatDate(createdAt))
            }

            if let updatedAt = task.updatedAt {
                detailRow(icon: "clock", label: "Updated", value: formatDate(updatedAt))
            }

            if let completedAt = task.completedAt {
                detailRow(icon: "checkmark.circle", label: "Completed", value: formatDate(completedAt))
            }
        }
        .cardStyle()
    }

    // MARK: - Linked Entities

    private func linkedEntitiesSection(_ entities: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Linked Entities")

            FlowLayout(spacing: 8) {
                ForEach(entities, id: \.self) { entity in
                    Text(entity)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
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

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 20)
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var statusColor: Color {
        switch task.status.lowercased() {
        case "in_progress": return AppTheme.statusInProgress
        case "pending": return AppTheme.statusPending
        case "completed": return AppTheme.statusCompleted
        case "blocked": return AppTheme.statusBlocked
        case "planned": return AppTheme.statusPlanned
        default: return AppTheme.textTertiary
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "critical": return AppTheme.priorityCritical
        case "high": return AppTheme.priorityHigh
        case "medium": return AppTheme.priorityMedium
        case "low": return AppTheme.priorityLow
        default: return AppTheme.textTertiary
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return dateString
    }
}

// MARK: - Flow Layout (for entity chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: AgentTask(
            id: 1,
            name: "Implement authentication flow",
            description: "Add OAuth2 support for the mobile app with biometric login fallback.",
            status: "in_progress",
            priority: "high",
            assignedTo: "Enigma",
            linkedEntities: ["OpenClaw", "Auth Service", "Mobile App"],
            parentTaskId: nil,
            createdAt: "2025-01-15T10:30:00Z",
            updatedAt: "2025-01-16T14:22:00Z",
            completedAt: nil
        ))
    }
}
