import Foundation

@MainActor
@Observable
final class StatsViewModel {
    private let mealStore: MealLogStore

    init(mealStore: MealLogStore = .shared) {
        self.mealStore = mealStore
    }

    // MARK: - 7-day calorie bars

    var calorieBars: [TrendBar] {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            let consumed = mealStore.meals
                .filter { cal.isDate($0.timestamp, inSameDayAs: d) }
                .reduce(0) { $0 + $1.adjustedCalories }
            return TrendBar(
                day: dayLabel(for: d),
                valueLabel: consumed > 0 ? "\(consumed)" : "—",
                progress: calorieTarget > 0 ? Double(consumed) / calorieTarget : 0,
                isToday: cal.isDateInToday(d)
            )
        }
    }

    // MARK: - Weekly macros vs targets

    var weeklyMacros: [Macro] {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        var protein = 0, carbs = 0, fat = 0
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            let ms = mealStore.meals.filter { cal.isDate($0.timestamp, inSameDayAs: d) }
            protein += ms.reduce(0) { $0 + $1.adjustedProtein }
            carbs   += ms.reduce(0) { $0 + $1.adjustedCarbs }
            fat     += ms.reduce(0) { $0 + $1.adjustedFat }
        }
        let p = savedProfile
        return [
            Macro(id: "protein", label: "Protein",
                  value: "\(protein / 7)g avg / \(p.proteinTargetG)g",
                  progress: Double(protein / 7) / Double(max(1, p.proteinTargetG)), colorKey: .plum),
            Macro(id: "carbs", label: "Carbs",
                  value: "\(carbs / 7)g avg / \(p.carbTargetG)g",
                  progress: Double(carbs / 7) / Double(max(1, p.carbTargetG)), colorKey: .ocean),
            Macro(id: "fat", label: "Fat",
                  value: "\(fat / 7)g avg / \(p.fatTargetG)g",
                  progress: Double(fat / 7) / Double(max(1, p.fatTargetG)), colorKey: .gold)
        ]
    }

    // MARK: - Summary metrics

    var weekAvgCalories: Int {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        var total = 0, days = 0
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            let consumed = mealStore.meals
                .filter { cal.isDate($0.timestamp, inSameDayAs: d) }
                .reduce(0) { $0 + $1.adjustedCalories }
            if consumed > 0 { total += consumed; days += 1 }
        }
        return days > 0 ? total / days : 0
    }

    var loggedDays: Int {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        return (0..<7).filter { i in
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            return mealStore.meals.contains { cal.isDate($0.timestamp, inSameDayAs: d) }
        }.count
    }

    var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date()), count = 0
        while mealStore.meals.contains(where: { cal.isDate($0.timestamp, inSameDayAs: day) }) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    var calorieTargetLabel: String { "\(Int(calorieTarget).formatted()) kcal" }

    // Best day: day with calorie intake closest to target
    var bestDayLabel: String? {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        let target = calorieTarget
        var bestDay: String?, bestDiff = Double.infinity
        let dayNames = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            let consumed = Double(mealStore.meals
                .filter { cal.isDate($0.timestamp, inSameDayAs: d) }
                .reduce(0) { $0 + $1.adjustedCalories })
            if consumed > 0 {
                let diff = abs(consumed - target)
                if diff < bestDiff { bestDiff = diff; bestDay = dayNames[i] }
            }
        }
        return bestDay
    }

    // Most frequently logged food name in the last 7 days
    var mostLoggedFood: String? {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        let recent = mealStore.meals.filter {
            guard let cutoff = cal.date(byAdding: .day, value: -7, to: today) else { return false }
            return $0.timestamp >= cutoff
        }
        guard !recent.isEmpty else { return nil }
        let counts = Dictionary(grouping: recent, by: { $0.name })
            .mapValues { $0.count }
            .max(by: { $0.value < $1.value })
        return counts?.key
    }

    // MARK: - Private helpers

    private var calorieTarget: Double { Double(savedProfile.calorieTarget) }

    private var savedProfile: UserProfile {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return UserProfile() }
        return snap.profile
    }

    private func dayLabel(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(1))
    }
}
