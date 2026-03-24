import SwiftUI

@main
struct OpenClawMobileApp: App {
    @State private var config = AppConfiguration()
    @State private var gateway = GatewayService()
    @State private var cronService = CronService()
    @State private var kgService = KnowledgeGraphService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(config)
                .environment(gateway)
                .environment(cronService)
                .environment(kgService)
                .preferredColorScheme(.dark)
                .task {
                    configureServices()
                    if config.isConfigured {
                        try? await gateway.connect()
                        await gateway.listSessions()
                        await gateway.fetchStatus()

                        // Restore last session or use first available
                        let sessionKey = config.lastSessionKey
                        if !sessionKey.isEmpty {
                            await gateway.switchSession(to: sessionKey)
                        } else if let first = gateway.sessions.first {
                            await gateway.switchSession(to: first.sessionKey)
                        }
                    }
                }
        }
    }

    private func configureServices() {
        gateway.configure(url: config.normalizedGatewayURL, token: config.gatewayToken)
        cronService.configure(url: config.normalizedGatewayURL, token: config.gatewayToken)
        kgService.configure(url: config.normalizedKGURL, token: config.kgAPIToken)
    }
}
