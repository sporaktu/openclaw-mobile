import Foundation

// MARK: - Knowledge Graph Service

@Observable
@MainActor
final class KnowledgeGraphService {
    var entities: [Entity] = []
    var tasks: [AgentTask] = []
    var stats: KGStats?
    var searchResults: [SearchResult] = []
    var isLoading = false
    var error: String?

    private var baseURL = ""
    private var token = ""

    func configure(url: String, token: String) {
        self.baseURL = url
        self.token = token
    }

    var isConfigured: Bool { !baseURL.isEmpty }

    // MARK: - Stats

    func fetchStats() async -> KGStats? {
        guard isConfigured else { return nil }
        do {
            let data = try await request(path: "/api/stats")
            let stats = try JSONDecoder().decode(KGStats.self, from: data)
            self.stats = stats
            return stats
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Entities

    func fetchEntities(type: String? = nil) async {
        guard isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var path = "/api/entities"
            if let type { path += "?type=\(type)" }
            let data = try await request(path: path)
            entities = try JSONDecoder().decode([Entity].self, from: data)
        } catch {
            self.error = "Failed to fetch entities: \(error.localizedDescription)"
        }
    }

    func fetchEntity(name: String) async -> Entity? {
        guard isConfigured else { return nil }
        do {
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            let data = try await request(path: "/api/entity/\(encodedName)")
            return try JSONDecoder().decode(Entity.self, from: data)
        } catch {
            self.error = "Failed to fetch entity: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Tasks

    func fetchTasks(status: String? = nil) async {
        guard isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var path = "/api/tasks"
            if let status { path += "?status=\(status)" }
            let data = try await request(path: path)
            tasks = try JSONDecoder().decode([AgentTask].self, from: data)
        } catch {
            self.error = "Failed to fetch tasks: \(error.localizedDescription)"
        }
    }

    // MARK: - Relationships

    func fetchRelationships(entity: String) async -> [Relationship] {
        guard isConfigured else { return [] }
        do {
            let encoded = entity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entity
            let data = try await request(path: "/api/relationships?entity=\(encoded)")
            return try JSONDecoder().decode([Relationship].self, from: data)
        } catch {
            self.error = "Failed to fetch relationships: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Graph

    func fetchGraph() async -> GraphData? {
        guard isConfigured else { return nil }
        do {
            let data = try await request(path: "/api/graph")
            return try JSONDecoder().decode(GraphData.self, from: data)
        } catch {
            self.error = "Failed to fetch graph: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Search

    func search(query: String) async {
        guard isConfigured, !query.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let data = try await request(path: "/api/search?q=\(encoded)")
            searchResults = try JSONDecoder().decode([SearchResult].self, from: data)
        } catch {
            self.error = "Failed to search: \(error.localizedDescription)"
        }
    }

    // MARK: - Network

    private func request(path: String) async throws -> Data {
        let urlString = baseURL + path
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "KGService", code: code,
                         userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
        }

        return data
    }
}
