import SwiftUI

/// Root tab interface. Uses iOS 26 value-based `Tab` items with the floating tab
/// bar that minimizes as the user scrolls down a tab's content.
struct MainTabView: View {

    /// The currently selected tab. Persisted across launches for continuity.
    @SceneStorage("selectedTab") private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            // Each `Tab`'s title string is its accessibility label automatically.
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                HomeView()
            }

            Tab(AppTab.plans.title, systemImage: AppTab.plans.systemImage, value: AppTab.plans) {
                PlansView()
            }

            Tab(AppTab.analytics.title, systemImage: AppTab.analytics.systemImage, value: AppTab.analytics) {
                AnalyticsView()
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// The app's top-level tabs. Raw value drives `SceneStorage` persistence.
private enum AppTab: String, Hashable {
    case home, plans, analytics, settings

    var title: String {
        switch self {
        case .home: String(localized: "Today")
        case .plans: String(localized: "Plans")
        case .analytics: String(localized: "Insights")
        case .settings: String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .plans: "calendar"
        case .analytics: "chart.bar.xaxis.ascending"
        case .settings: "gearshape.fill"
        }
    }
}

#if DEBUG
#Preview {
    let container = SharedModelContainer.preview()
    MainTabView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}
#endif
