import Foundation
import WidgetKit

/// App Group shared between the main app and the widget extension.
enum AppGroup {
    static let id = "group.com.wydfcc.calbro"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

/// Today's nutrition snapshot written by the app, read by the widget.
struct WidgetNutritionSnapshot: Codable, Equatable {
    var date: Date
    var caloriesConsumed: Int
    var calorieTarget: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var proteinTarget: Int
    var carbTarget: Int
    var fatTarget: Int

    var remaining: Int { max(0, calorieTarget - caloriesConsumed) }
    var progress: Double {
        calorieTarget > 0 ? min(1, Double(caloriesConsumed) / Double(calorieTarget)) : 0
    }

    static let placeholder = WidgetNutritionSnapshot(
        date: Date(), caloriesConsumed: 1240, calorieTarget: 1820,
        protein: 82, carbs: 148, fat: 38,
        proteinTarget: 150, carbTarget: 180, fatTarget: 60
    )

    static func empty(target: Int = 1820) -> WidgetNutritionSnapshot {
        WidgetNutritionSnapshot(
            date: Date(), caloriesConsumed: 0, calorieTarget: target,
            protein: 0, carbs: 0, fat: 0,
            proteinTarget: 150, carbTarget: 180, fatTarget: 60
        )
    }
}

/// Bridges nutrition data into the App Group container and refreshes widget timelines.
enum SharedNutritionStore {
    private static let key = "widget.today.v1"

    static func save(_ snapshot: WidgetNutritionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Returns today's snapshot, or an empty one if missing/stale (different day).
    static func load() -> WidgetNutritionSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetNutritionSnapshot.self, from: data),
              Calendar.current.isDateInToday(snapshot.date)
        else { return .empty() }
        return snapshot
    }
}
