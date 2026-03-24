import SwiftUI

struct ContentView: View {
    @Environment(AppConfiguration.self) private var config
    @Environment(GatewayService.self) private var gateway
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: 0) {
                ChatContainerView()
            }

            Tab("Sessions", systemImage: "rectangle.stack", value: 1) {
                SessionsListView()
            }

            Tab("Crons", systemImage: "clock.arrow.2.circlepath", value: 2) {
                CronsListView()
            }

            Tab("Settings", systemImage: "gear", value: 3) {
                SettingsView()
            }
        }
        .tint(AppTheme.accent)
        .onAppear {
            configureTabBarAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToChat)) { _ in
            selectedTab = 0
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.background)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(AppTheme.textTertiary)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textTertiary)]
        itemAppearance.selected.iconColor = UIColor(AppTheme.accent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.accent)]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .environment(AppConfiguration())
        .environment(GatewayService())
        .environment(CronService())
        .environment(KnowledgeGraphService())
}
