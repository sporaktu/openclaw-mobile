import Foundation

// MARK: - Cron Service (REST API)

@Observable
@MainActor
final class CronService {
    var jobs: [CronJob] = []
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

    // MARK: - CRUD

    func fetchJobs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: [String: Any] = try await request("GET", path: "/api/crons")
            if let inner = result["result"] as? [String: Any],
               let jobsArray = inner["jobs"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: jobsArray)
                jobs = try JSONDecoder().decode([CronJob].self, from: data)
            }
        } catch {
            self.error = "Failed to load crons: \(error.localizedDescription)"
        }
    }

    func createJob(_ payload: CreateCronPayload) async throws {
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)
        let payloadDict = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] ?? [:]

        let _: [String: Any] = try await request("POST", path: "/api/crons", body: ["job": payloadDict])
        await fetchJobs() // refresh
    }

    func updateJob(id: String, patch: [String: Any]) async throws {
        let _: [String: Any] = try await request("PATCH", path: "/api/crons/\(id)", body: ["patch": patch])
        await fetchJobs()
    }

    func deleteJob(id: String) async throws {
        let _: [String: Any] = try await request("DELETE", path: "/api/crons/\(id)")
        jobs.removeAll { $0.id == id }
    }

    func toggleJob(id: String, enabled: Bool) async throws {
        let _: [String: Any] = try await request("POST", path: "/api/crons/\(id)/toggle", body: ["enabled": enabled])
        if let idx = jobs.firstIndex(where: { $0.id == id }) {
            jobs[idx].enabled = enabled
        }
    }

    func runJob(id: String) async throws {
        let _: [String: Any] = try await request("POST", path: "/api/crons/\(id)/run")
    }

    func fetchRuns(id: String) async throws -> [CronRun] {
        let result: [String: Any] = try await request("GET", path: "/api/crons/\(id)/runs")
        if let inner = result["result"] as? [String: Any],
           let runsArray = inner["runs"] as? [[String: Any]] {
            let data = try JSONSerialization.data(withJSONObject: runsArray)
            return try JSONDecoder().decode([CronRun].self, from: data)
        }
        return []
    }

    // MARK: - Private

    private func request(_ method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard !baseURL.isEmpty else { throw CronServiceError.notConfigured }

        guard let url = URL(string: baseURL + path) else {
            throw CronServiceError.invalidURL
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
            throw CronServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CronServiceError.httpError(httpResponse.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CronServiceError.invalidResponse
        }

        return json
    }
}

enum CronServiceError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Cron service not configured"
        case .invalidURL: "Invalid cron API URL"
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        }
    }
}
