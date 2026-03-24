import Foundation

// MARK: - Kanban Task

struct KanbanTask: Codable, Identifiable, Sendable {
    let id: String
    var title: String
    var description: String?
    var status: TaskStatus
    var priority: TaskPriority
    var createdBy: String?
    var createdAt: Double?
    var updatedAt: Double?
    var version: Int
    var assignee: String?
    var labels: [String]
    var columnOrder: Int

    var createdDate: Date? {
        guard let ts = createdAt else { return nil }
        return Date(timeIntervalSince1970: ts / 1000)
    }

    var updatedDate: Date? {
        guard let ts = updatedAt else { return nil }
        return Date(timeIntervalSince1970: ts / 1000)
    }
}

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case backlog
    case todo
    case inProgress = "in-progress"
    case review
    case done
    case cancelled

    var label: String {
        switch self {
        case .backlog: "Backlog"
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .review: "Review"
        case .done: "Done"
        case .cancelled: "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .backlog: "tray"
        case .todo: "circle"
        case .inProgress: "play.circle.fill"
        case .review: "eye.circle"
        case .done: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    /// Columns shown on the kanban board
    static let boardColumns: [TaskStatus] = [.backlog, .todo, .inProgress, .review, .done]
}

enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case critical
    case high
    case normal
    case low

    var label: String {
        rawValue.capitalized
    }
}
