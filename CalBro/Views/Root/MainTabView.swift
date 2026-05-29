import SwiftUI

struct MainTabView: View {
    @State private var nav          = AppNavigationViewModel()
    @State private var dashboard    = DashboardViewModel()
    @State private var nutrition    = NutritionViewModel()
    @State private var calendar     = CalendarViewModel()
    @State private var stats        = StatsViewModel()
    @State private var goals        = GoalsViewModel()
    @State private var integrations = IntegrationViewModel()

    init(profile: UserProfile = UserProfile()) {
        _goals     = State(initialValue: GoalsViewModel(profile: profile, predictionService: RealPredictionService()))
        _dashboard = State(initialValue: DashboardViewModel())
    }

    var body: some View {
        @Bindable var nav = nav

        if #available(iOS 26.0, *) {
            TabView(selection: $nav.selectedTab) {
                Tab("Today", systemImage: AppTab.today.symbol, value: AppTab.today) {
                    todayStack(nav: nav)
                }
                Tab("Stats", systemImage: AppTab.stats.symbol, value: AppTab.stats) {
                    statsStack(nav: nav)
                }
                Tab("Profile", systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                    profileStack(nav: nav)
                }
            }
            .fullScreenCover(item: $nav.presentedSheet) { _ in
                CameraFlowView(onClose: { nav.dismissSheet() })
            }
        } else {
            legacyLayout(nav: nav)
        }
    }

    // MARK: - Stacks

    @ViewBuilder
    private func todayStack(nav navModel: AppNavigationViewModel) -> some View {
        @Bindable var nav = navModel
        NavigationStack(path: $nav.todayPath) {
            DashboardView(viewModel: dashboard, navigation: navModel)
                .navigationDestination(for: AppRoute.self) { destination(for: $0) }
        }
    }

    @ViewBuilder
    private func statsStack(nav navModel: AppNavigationViewModel) -> some View {
        @Bindable var nav = navModel
        NavigationStack(path: $nav.statsPath) {
            StatsCaloriesView(viewModel: stats, navigation: navModel)
                .navigationDestination(for: AppRoute.self) { destination(for: $0) }
        }
    }

    @ViewBuilder
    private func profileStack(nav navModel: AppNavigationViewModel) -> some View {
        @Bindable var nav = navModel
        NavigationStack(path: $nav.profilePath) {
            ProfileHubView(navigation: navModel, goals: goals)
                .navigationDestination(for: AppRoute.self) { destination(for: $0) }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .nutrition:    NutritionDetailView(viewModel: nutrition)
        case .calendar:     CalendarMonthView(viewModel: calendar)
        case .weeklyReport: StatsReportView(stats: stats)
        case .goals:        GoalsOverviewView(viewModel: goals)
        case .prediction:   WeightPredictionView(viewModel: goals)
        case .plateau:      PlateauAlertView()
        case .integrations: HealthKitSyncView(viewModel: integrations)
        case .widgets:      WidgetPreviewView(viewModel: integrations)
        }
    }

    // MARK: - Legacy layout (pre-iOS 26)

    @ViewBuilder
    private func legacyLayout(nav navModel: AppNavigationViewModel) -> some View {
        @Bindable var nav = navModel
        ZStack(alignment: .bottom) {
            Group {
                switch nav.selectedTab {
                case .today:   todayStack(nav: navModel)
                case .log:     CameraFlowView(onClose: { nav.selectedTab = .today })
                case .stats:   statsStack(nav: navModel)
                case .profile: profileStack(nav: navModel)
                }
            }
            BottomTabBar(selectedTab: $nav.selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .sheet(item: $nav.presentedSheet) { _ in
            CameraFlowView(onClose: { nav.dismissSheet() })
                .presentationDetents([.large])
        }
    }
}
