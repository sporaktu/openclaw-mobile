import SwiftUI
import WidgetKit

// MARK: - Widget Bundle

@main
struct OpenClawWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        LastMessageWidget()
        ActiveTasksWidget()
    }
}
