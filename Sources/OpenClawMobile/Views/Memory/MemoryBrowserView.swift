import SwiftUI

struct MemoryBrowserView: View {
    @Environment(MemoryService.self) private var memoryService

    @State private var searchText = ""
    @State private var selectedFile: MemoryFile?

    var body: some View {
        NavigationStack {
            List {
                if !memoryService.memories.isEmpty {
                    memoriesSection
                }

                if !memoryService.files.isEmpty {
                    filesSection
                }

                if memoryService.memories.isEmpty && memoryService.files.isEmpty && !memoryService.isLoading {
                    ContentUnavailableView(
                        "No Memories",
                        systemImage: "brain",
                        description: Text("Memory files will appear here once the agent has stored memories.")
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Memory")
            .searchable(text: $searchText, prompt: "Search memories")
            .refreshable {
                await memoryService.fetchMemories()
            }
            .overlay {
                if memoryService.isLoading && memoryService.memories.isEmpty {
                    ProgressView("Loading memories…")
                }
            }
            .task {
                if memoryService.memories.isEmpty {
                    await memoryService.fetchMemories()
                }
            }
            .navigationDestination(item: $selectedFile) { file in
                MemoryFileView(file: file)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var memoriesSection: some View {
        let filtered = searchText.isEmpty
            ? memoryService.memories
            : memoryService.search(query: searchText)

        Section("Memories") {
            ForEach(filtered) { memory in
                memoryRow(memory)
            }
        }
    }

    private var filesSection: some View {
        Section("Files") {
            ForEach(memoryService.files) { file in
                Button {
                    selectedFile = file
                } label: {
                    HStack {
                        Image(systemName: file.isDaily ? "calendar" : "doc.text")
                            .foregroundStyle(file.isDaily ? AppTheme.accent : AppTheme.textSecondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.displayName)
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textPrimary)

                            if file.isDaily {
                                Text(file.name)
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Memory Row

    private func memoryRow(_ memory: Memory) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(memoryTypeColor(memory.type))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(memory.text)
                    .font(memory.type == .section ? AppTheme.captionFont : AppTheme.bodyFont)
                    .fontWeight(memory.type == .section ? .semibold : .regular)
                    .foregroundStyle(memory.type == .section ? AppTheme.accent : AppTheme.textPrimary)
                    .lineLimit(memory.type == .section ? 1 : 4)

                if let date = memory.date {
                    Text(date)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .listRowBackground(AppTheme.cardBackground)
    }

    private func memoryTypeColor(_ type: Memory.MemoryType) -> Color {
        switch type {
        case .section: AppTheme.accent
        case .item: AppTheme.textTertiary
        case .daily: AppTheme.statusPending
        }
    }
}

// MARK: - Make MemoryFile Hashable for navigationDestination

extension MemoryFile: Hashable {
    static func == (lhs: MemoryFile, rhs: MemoryFile) -> Bool {
        lhs.path == rhs.path
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
}

#Preview {
    MemoryBrowserView()
        .environment(MemoryService())
        .preferredColorScheme(.dark)
}
