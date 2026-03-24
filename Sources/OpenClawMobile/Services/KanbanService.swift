import Foundation

// MARK: - Kanban Service (REST API)

@Observable
@MainActor
final class KanbanService {
    var tasks: [KanbanTask] = []
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

    // MARK: - Fetch

    func fetchTasks(query: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            var path = "/api/kanban/tasks?limit=200"
            if let query, !query.isEmpty {
                path += "&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            }
            let result: [String: Any] = try await request("GET", path: path)
            if let items = result["items"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: items)
                tasks = try JSONDecoder().decode([KanbanTask].self, from: data)
            }
        } catch {
            self.error = "Failed to load tasks: \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD

    func createTask(title: String, description: String? = nil, status: TaskStatus = .todo, priority: TaskPriority = .normal) async throws {
        var body: [String: Any] = [
            "title": title,
            "status": status.rawValue,
            "priority": priority.rawValue
        ]
        if let description { body["description"] = description }

        let _: [String: Any] = try await request("POST", path: "/api/kanban/tasks", body: body)
        await fetchTasks()
    }

    func updateTask(id: String, status: TaskStatus? = nil, priority: TaskPriority? = nil, title: String? = nil, version: Int) async throws {
        var body: [String: Any] = ["version": version]
        if let status { body["status"] = status.rawValue }
        if let priority { body["priority"] = priority.rawValue }
        if let title { body["title"] = title }

        let _: [String: Any] = try await request("PATCH", path: "/api/kanban/tasks/\(id)", body: body)
        await fetchTasks()
    }

    func deleteTask(id: String) async throws {
        let _: [String: Any] = try await request("DELETE", path: "/api/kanban/tasks/\(id)")
        tasks.removeAll { $0.id == id }
    }

    func moveTask(id: String, to status: TaskStatus, version: Int) async throws {
        try await updateTask(id: id, status: status, version: version)
    }

    // MARK: - Computed

    func tasks(for status: TaskStatus) -> [KanbanTask] {
        tasks.filter { $0.status == status }
            .sorted { $0.columnOrder < $1.columnOrder }
    }

    var statusCounts: [TaskStatus: Int] {
        var counts: [TaskStatus: Int] = [:]
        for status in TaskStatus.allCases {
            counts[status] = tasks.filter { $0.status == status }.count
        }
        return counts
    }

    var inProgressTasks: [KanbanTask] {
        tasks(for: .inProgress)
    }

    // MARK: - Private

    private func request(_ method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard !baseURL.isEmpty else { throw KanbanServiceError.notConfigured }

        guard let url = URL(string: baseURL + path) else {
            throw KanbanServiceError.invalidURL
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
            throw KanbanServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw KanbanServiceError.httpError(httpResponse.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KanbanServiceError.invalidResponse
        }

        return json
    }
}

enum KanbanServiceError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Kanban service not configured"
        case .invalidURL: "Invalid kanban API URL"
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        }
    }
}
