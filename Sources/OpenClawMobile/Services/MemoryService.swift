import Foundation

// MARK: - Memory Service (REST API)

@Observable
@MainActor
final class MemoryService {
    var memories: [Memory] = []
    var files: [MemoryFile] = []
    var isLoading = false
    var error: String?

    private var baseURL = ""
    private var token = ""

    func configure(url: String, token: String) {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSuffix("/") { normalized.removeLast() }
        self.baseURL = normalized
        self.token = token
    }

    // MARK: - Fetch Memories

    func fetchMemories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: [String: Any] = try await request("GET", path: "/api/memories")
            if let items = result as? [[String: Any]] {
                memories = items.compactMap { parseMemory($0) }
            } else if let items = result["memories"] as? [[String: Any]] {
                memories = items.compactMap { parseMemory($0) }
            } else if let items = result["result"] as? [[String: Any]] {
                memories = items.compactMap { parseMemory($0) }
            }
        } catch {
            // Try workspace.list as fallback for file listing
            await fetchMemoryFiles()
        }
    }

    // MARK: - Fetch Memory Files (via workspace API)

    func fetchMemoryFiles() async {
        do {
            let result: [String: Any] = try await request("GET", path: "/api/workspace/list", query: "path=memory")
            if let items = result["files"] as? [[String: Any]] {
                files = items.compactMap { dict -> MemoryFile? in
                    guard let path = dict["path"] as? String,
                          let name = dict["name"] as? String else { return nil }
                    let isDaily = name.range(of: #"^\d{4}-\d{2}-\d{2}\.md$"#, options: .regularExpression) != nil
                    return MemoryFile(path: path, name: name, isDaily: isDaily)
                }
                // Also add MEMORY.md at root
                files.insert(MemoryFile(path: "MEMORY.md", name: "MEMORY.md", isDaily: false), at: 0)
            }
        } catch {
            self.error = "Failed to load memory files: \(error.localizedDescription)"
        }
    }

    // MARK: - Read File Content

    func readFile(path: String) async -> String? {
        do {
            let result: [String: Any] = try await request("GET", path: "/api/workspace/read", query: "path=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path)")
            return result["content"] as? String
                ?? result["text"] as? String
        } catch {
            self.error = "Failed to read file: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Search

    func search(query: String) -> [Memory] {
        guard !query.isEmpty else { return memories }
        let q = query.lowercased()
        return memories.filter { $0.text.lowercased().contains(q) }
    }

    // MARK: - Private

    private func parseMemory(_ dict: [String: Any]) -> Memory? {
        guard let text = dict["text"] as? String,
              let typeStr = dict["type"] as? String,
              let type = Memory.MemoryType(rawValue: typeStr) else { return nil }
        return Memory(type: type, text: text, date: dict["date"] as? String)
    }

    private func request(_ method: String, path: String, query: String? = nil, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard !baseURL.isEmpty else { throw MemoryServiceError.notConfigured }

        var urlString = baseURL + path
        if let query { urlString += "?\(query)" }

        guard let url = URL(string: urlString) else {
            throw MemoryServiceError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MemoryServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MemoryServiceError.httpError(httpResponse.statusCode, body)
        }

        // Response might be an array or object
        let json = try JSONSerialization.jsonObject(with: data)
        if let dict = json as? [String: Any] {
            return dict
        }
        if let array = json as? [[String: Any]] {
            return ["memories": array] as [String: Any]
        }
        throw MemoryServiceError.invalidResponse
    }
}

enum MemoryServiceError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Memory service not configured"
        case .invalidURL: "Invalid memory API URL"
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        }
    }
}
