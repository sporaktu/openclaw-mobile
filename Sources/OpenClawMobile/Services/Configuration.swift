import SwiftUI

// MARK: - App Configuration

@Observable
@MainActor
final class AppConfiguration {
    // Gateway URL stored in UserDefaults (not sensitive)
    @ObservationIgnored
    @AppStorage("gatewayURL") var gatewayURL: String = ""

    // Token stored in Keychain (sensitive)
    var gatewayToken: String {
        get { KeychainService.load(key: "gatewayToken") ?? "" }
        set { try? KeychainService.save(key: "gatewayToken", value: newValue) }
    }

    // Knowledge Graph
    @ObservationIgnored
    @AppStorage("kgAPIURL") var kgAPIURL: String = ""

    @ObservationIgnored
    @AppStorage("kgAPIToken") var kgAPIToken: String = "enigma-kg-local"

    // Last active session
    @ObservationIgnored
    @AppStorage("lastSessionKey") var lastSessionKey: String = "mobile"

    // Connection status (transient)
    var gatewayConnected = false
    var kgConnected = false
    var agentName = ""

    var isConfigured: Bool {
        !gatewayURL.isEmpty && !gatewayToken.isEmpty
    }

    var isKGConfigured: Bool {
        !kgAPIURL.isEmpty
    }

    var normalizedGatewayURL: String {
        var url = gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url.removeLast() }
        return url
    }

    var normalizedKGURL: String {
        var url = kgAPIURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url.removeLast() }
        return url
    }
}
