import Foundation

@Observable
@MainActor
final class MealLogStore {
    static let shared = MealLogStore()

    private(set) var meals: [LoggedMeal] = []
    private let key = "calbro.meals.v1"

    init() { load() }

    func log(_ meal: LoggedMeal) {
        meals.append(meal)
        save()
    }

    func update(_ meal: LoggedMeal) {
        guard let i = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[i] = meal
        save()
    }

    func remove(id: UUID) {
        meals.removeAll { $0.id == id }
        save()
    }

    func mealsForToday() -> [LoggedMeal] {
        meals.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    func totalsForToday() -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let today = mealsForToday()
        return (
            today.reduce(0) { $0 + $1.adjustedCalories },
            today.reduce(0) { $0 + $1.adjustedProtein },
            today.reduce(0) { $0 + $1.adjustedCarbs },
            today.reduce(0) { $0 + $1.adjustedFat }
        )
    }

    private func save() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        meals = meals.filter { $0.timestamp > cutoff }
        if let data = try? JSONEncoder().encode(meals) {
            UserDefaults.standard.set(data, forKey: key)
        }
        syncWidget()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([LoggedMeal].self, from: data)
        else { return }
        meals = saved
        syncWidget()
    }

    // MARK: - Widget + reminder bridge

    /// Pushes today's totals into the App Group container so the widget reflects real data,
    /// and fires the calorie-warning notification when crossing the 90% threshold.
    private func syncWidget() {
        let totals = totalsForToday()
        let profile = currentProfile()
        let snapshot = WidgetNutritionSnapshot(
            date: Date(),
            caloriesConsumed: totals.calories,
            calorieTarget: profile.calorieTarget,
            protein: totals.protein, carbs: totals.carbs, fat: totals.fat,
            proteinTarget: profile.proteinTargetG,
            carbTarget: profile.carbTargetG,
            fatTarget: profile.fatTargetG
        )
        SharedNutritionStore.save(snapshot)
        CalorieWarningNotifier.evaluate(consumed: totals.calories, target: profile.calorieTarget)
    }

    private func currentProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return UserProfile() }
        return snap.profile
    }
}
