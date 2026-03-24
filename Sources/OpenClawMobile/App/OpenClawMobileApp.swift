import SwiftUI

@main
struct OpenClawMobileApp: App {
    @State private var config = AppConfiguration()
    @State private var gateway = GatewayService()
    @State private var cronService = CronService()
    @State private var kgService = KnowledgeGraphService()
    @State private var memoryService = MemoryService()
    @State private var kanbanService = KanbanService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(config)
                .environment(gateway)
                .environment(cronService)
                .environment(kgService)
                .environment(memoryService)
                .environment(kanbanService)
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

                        // Push initial data to widgets
                        WidgetDataWriter.update(gateway: gateway, kanbanService: kanbanService)
                    }
                }
                .onChange(of: gateway.messages.count) {
                    WidgetDataWriter.update(gateway: gateway, kanbanService: kanbanService)
                }
                .onChange(of: gateway.isConnected) {
                    WidgetDataWriter.update(gateway: gateway, kanbanService: kanbanService)
                }
        }
    }

    private func configureServices() {
        let url = config.normalizedGatewayURL
        let token = config.gatewayToken
        gateway.configure(url: url, token: token)
        cronService.configure(url: url, token: token)
        memoryService.configure(url: url, token: token)
        kanbanService.configure(url: url, token: token)
        kgService.configure(url: config.normalizedKGURL, token: config.kgAPIToken)
    }
}
