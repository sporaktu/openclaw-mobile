import SwiftUI

struct MemoryFileView: View {
    let file: MemoryFile

    @Environment(MemoryService.self) private var memoryService
    @State private var content: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let content {
                MarkdownText(content)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ContentUnavailableView(
                    "Could not load file",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The file might not exist or the gateway is unreachable.")
                )
            }
        }
        .background(AppTheme.background)
        .navigationTitle(file.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            content = await memoryService.readFile(path: file.path)
            isLoading = false
        }
        .refreshable {
            content = await memoryService.readFile(path: file.path)
        }
    }
}

#Preview {
    NavigationStack {
        MemoryFileView(file: MemoryFile(path: "MEMORY.md", name: "MEMORY.md", isDaily: false))
    }
    .environment(MemoryService())
    .preferredColorScheme(.dark)
}
