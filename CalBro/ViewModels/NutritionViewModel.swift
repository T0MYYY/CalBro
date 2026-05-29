import Foundation

@MainActor
@Observable
final class NutritionViewModel {
    private let mealStore: MealLogStore

    static let mockMicros: [Micronutrient] = []

    init(mealStore: MealLogStore = .shared) {
        self.mealStore = mealStore
    }

    var dailyNutrition: DailyNutrition {
        let t = mealStore.totalsForToday()
        let p = savedProfile
        return DailyNutrition(
            caloriesConsumed: t.calories,
            calorieTarget: p.calorieTarget,
            macros: [
                Macro(id: "calories", label: "Calories",
                      value: "\(t.calories)",
                      progress: Double(t.calories) / Double(p.calorieTarget),
                      colorKey: .terra),
                Macro(id: "protein", label: "Protein",
                      value: "\(t.protein)g",
                      progress: Double(t.protein) / Double(max(1, p.proteinTargetG)),
                      colorKey: .plum),
                Macro(id: "carbs", label: "Carbs",
                      value: "\(t.carbs)g",
                      progress: Double(t.carbs) / Double(max(1, p.carbTargetG)),
                      colorKey: .ocean),
                Macro(id: "fat", label: "Fat",
                      value: "\(t.fat)g",
                      progress: Double(t.fat) / Double(max(1, p.fatTargetG)),
                      colorKey: .gold)
            ],
            micronutrients: []
        )
    }

    var todaysMeals: [LoggedMeal] { mealStore.mealsForToday() }

    private var savedProfile: UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return UserProfile() }
        return snap.profile
    }
}
