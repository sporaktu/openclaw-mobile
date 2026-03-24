import Foundation

// MARK: - Memory Models

struct Memory: Codable, Identifiable, Sendable {
    var id: String { "\(type)-\(text.prefix(40))-\(date ?? "")" }

    let type: MemoryType
    let text: String
    var date: String?

    enum MemoryType: String, Codable, Sendable {
        case section
        case item
        case daily
    }
}

struct MemoryFile: Identifiable, Sendable {
    var id: String { path }
    let path: String
    let name: String
    let isDaily: Bool

    var displayName: String {
        if isDaily, let date = extractDate() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return name
    }

    private func extractDate() -> Date? {
        // Extract YYYY-MM-DD from filename like "2025-03-20.md"
        let base = (name as NSString).deletingPathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: base)
    }
}
