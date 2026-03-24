import SwiftUI

struct KanbanBoardView: View {
    @Environment(KanbanService.self) private var kanbanService

    @State private var selectedTask: KanbanTask?
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if kanbanService.isLoading && kanbanService.tasks.isEmpty {
                    ProgressView("Loading tasks…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if kanbanService.tasks.isEmpty {
                    emptyState
                } else {
                    boardContent
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Kanban")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await kanbanService.fetchTasks()
            }
            .task {
                if kanbanService.tasks.isEmpty {
                    await kanbanService.fetchTasks()
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheetView(task: task)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateTaskSheetView()
            }
        }
    }

    // MARK: - Board

    private var boardContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(TaskStatus.boardColumns, id: \.rawValue) { status in
                    KanbanColumnView(
                        status: status,
                        tasks: kanbanService.tasks(for: status)
                    ) { task in
                        selectedTask = task
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: "checklist")
        } description: {
            Text("Create your first task or ask the agent to propose one.")
        } actions: {
            Button("Create Task") {
                showCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }
}

// MARK: - Task Detail Sheet

private struct TaskDetailSheetView: View {
    let task: KanbanTask
    @Environment(KanbanService.self) private var kanbanService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: TaskStatus

    init(task: KanbanTask) {
        self.task = task
        self._selectedStatus = State(initialValue: task.status)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Details") {
                    LabeledContent("Title", value: task.title)
                    if let desc = task.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textTertiary)
                            MarkdownText(desc)
                        }
                    }
                    LabeledContent("Priority", value: task.priority.label)
                    if let assignee = task.assignee {
                        LabeledContent("Assignee", value: assignee)
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(TaskStatus.boardColumns, id: \.rawValue) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedStatus) { _, newStatus in
                        guard newStatus != task.status else { return }
                        Task {
                            try? await kanbanService.moveTask(
                                id: task.id,
                                to: newStatus,
                                version: task.version
                            )
                            dismiss()
                        }
                    }
                }

                if !task.labels.isEmpty {
                    Section("Labels") {
                        KanbanFlowLayout(spacing: 6) {
                            ForEach(task.labels, id: \.self) { label in
                                Text(label)
                                    .font(AppTheme.captionFont)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.accent.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Section {
                    Button("Delete Task", role: .destructive) {
                        Task {
                            try? await kanbanService.deleteTask(id: task.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Create Task Sheet

private struct CreateTaskSheetView: View {
    @Environment(KanbanService.self) private var kanbanService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var status: TaskStatus = .todo
    @State private var priority: TaskPriority = .normal
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Options") {
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.boardColumns, id: \.rawValue) { s in
                            Text(s.label).tag(s)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.rawValue) { p in
                            Text(p.label).tag(p)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }

    private func createTask() {
        isCreating = true
        Task {
            try? await kanbanService.createTask(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                status: status,
                priority: priority
            )
            dismiss()
        }
    }
}

// MARK: - Kanban Flow Layout (for labels)

private struct KanbanFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

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
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions
        )
    }
}

// MARK: - Make KanbanTask conform to Identifiable for sheet

extension KanbanTask: Hashable {
    static func == (lhs: KanbanTask, rhs: KanbanTask) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    KanbanBoardView()
        .environment(KanbanService())
        .preferredColorScheme(.dark)
}
