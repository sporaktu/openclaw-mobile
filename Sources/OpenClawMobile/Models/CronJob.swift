import Foundation

/// A scheduled cron job from the gateway REST API.
struct CronJob: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String?
    var label: String?
    var enabled: Bool

    // Schedule (one of: every, cron, at)
    var scheduleKind: String        // "every", "cron", "at"
    var schedule: String?           // cron expression
    var scheduleTz: String?         // timezone
    var everyMs: Int?               // interval in milliseconds
    var at: String?                 // ISO datetime for one-shot

    // Payload
    var payloadKind: String         // "agentTurn", "systemEvent"
    var message: String?            // task message or event text
    var model: String?

    // State
    var lastRun: String?            // ISO timestamp
    var lastStatus: String?         // "success", "error", etc.
    var lastError: String?

    var effectiveName: String {
        name ?? label ?? id
    }

    var humanSchedule: String {
        switch scheduleKind {
        case "every":
            guard let ms = everyMs else { return "unknown" }
            let minutes = ms / 60_000
            if minutes < 60 { return "Every \(minutes)m" }
            let hours = minutes / 60
            if hours < 24 { return "Every \(hours)h" }
            return "Every \(hours / 24)d"
        case "cron":
            return schedule ?? "unknown"
        case "at":
            return at ?? "one-time"
        default:
            return "unknown"
        }
    }

    var lastRunDate: Date? {
        guard let str = lastRun else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }
}

/// A single run record for a cron job.
struct CronRun: Codable, Identifiable, Sendable {
    var id: String { timestamp }
    let timestamp: String
    let status: String              // "success", "error", "timeout"
    var duration: Int?              // milliseconds
    var error: String?
    var summary: String?

    var statusColor: String {
        switch status {
        case "success": "green"
        case "error": "red"
        case "timeout": "orange"
        default: "gray"
        }
    }
}

/// Payload for creating a new cron job.
struct CreateCronPayload: Codable, Sendable {
    let name: String
    let scheduleKind: String
    var schedule: String?
    var everyMs: Int?
    let payloadKind: String
    let message: String
    var model: String?
    let enabled: Bool
}
