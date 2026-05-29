import Foundation

struct AppStateSnapshot: Codable, Equatable {
    var onboardingComplete: Bool
    var profile: UserProfile
}

protocol AppStateStore: Sendable {
    func load() -> AppStateSnapshot?
    func save(_ snapshot: AppStateSnapshot)
    func clear()
}

final class UserDefaultsAppStateStore: AppStateStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "calBuddy.appState.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AppStateSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
    }

    func save(_ snapshot: AppStateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
