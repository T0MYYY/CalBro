import SwiftUI

enum AppTab: String, Identifiable, Codable, Equatable, Hashable {
    case today   = "Today"
    case log     = "Log"
    case stats   = "Stats"
    case profile = "Profile"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today:   "circle.grid.cross.fill"
        case .log:     "camera.fill"
        case .stats:   "chart.bar.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

enum AppRoute: Hashable {
    case nutrition
    case calendar
    case weeklyReport
    case goals
    case prediction
    case plateau
    case integrations
    case widgets
}

enum AppSheet: Identifiable {
    case camera
    var id: String { "camera" }
}

@MainActor
@Observable
final class AppNavigationViewModel {
    var selectedTab: AppTab = .today
    var todayPath:   [AppRoute] = []
    var statsPath:   [AppRoute] = []
    var profilePath: [AppRoute] = []
    var presentedSheet: AppSheet?

    // Camera is presented modally from the Today + button (no dedicated tab).
    func showCameraSheet() {
        presentedSheet = .camera
    }

    func dismissSheet() { presentedSheet = nil }

    func navigate(_ route: AppRoute, in tab: AppTab? = nil) {
        switch tab ?? selectedTab {
        case .today:   todayPath.append(route)
        case .stats:   statsPath.append(route)
        case .profile: profilePath.append(route)
        case .log:     selectedTab = .log
        }
    }
}
