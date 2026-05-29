import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    var selectedWeekdayIndex: Int

    private let mealStore: MealLogStore

    init(mealStore: MealLogStore = .shared) {
        self.mealStore = mealStore
        let weekday = Calendar.current.component(.weekday, from: Date())
        self.selectedWeekdayIndex = (weekday + 5) % 7
    }

    // Read live from UserDefaults so profile edits reflect without restart
    private var savedProfile: UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return UserProfile() }
        return snap.profile
    }

    // MARK: - Daily nutrition

    var nutrition: DailyNutrition {
        let t = mealStore.totalsForToday()
        let p = savedProfile
        return DailyNutrition(
            caloriesConsumed: t.calories,
            calorieTarget: p.calorieTarget,
            macros: [
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

    var meals: [Meal] {
        mealStore.mealsForToday().map {
            Meal(id: $0.id.uuidString, name: $0.name,
                 time: $0.timeLabel, calories: $0.adjustedCalories, isLogged: true)
        }
    }

    var hasNoMeals: Bool { mealStore.mealsForToday().isEmpty }

    // MARK: - Week strip

    var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    var streakLabel: String {
        let s = streak
        return s > 1 ? "\(s)-day streak 🔥" : s == 1 ? "Started today 🌱" : "Log today!"
    }

    var days: [String]  { ["M","T","W","T","F","S","S"] }

    var dates: [Int] {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        let offset = (cal.component(.weekday, from: today) + 5) % 7
        return (0..<7).map { i in cal.component(.day, from: cal.date(byAdding: .day, value: i - offset, to: today)!) }
    }

    var dayStatuses: [NutritionColorKey] {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        let offset = (cal.component(.weekday, from: today) + 5) % 7
        let target = savedProfile.calorieTarget
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i - offset, to: today)!
            if d > today { return .ink }
            let consumed = mealStore.meals
                .filter { cal.isDate($0.timestamp, inSameDayAs: d) }
                .reduce(0) { $0 + $1.adjustedCalories }
            if consumed == 0 { return .ink }
            return consumed >= Int(Double(target) * 0.80) ? .sage : .terra
        }
    }

    func selectWeekday(_ idx: Int) { selectedWeekdayIndex = idx }

    private var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date()), count = 0
        while mealStore.meals.contains(where: { cal.isDate($0.timestamp, inSameDayAs: day) }) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}
