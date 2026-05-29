import Foundation

struct Macro: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let progress: Double
    let colorKey: NutritionColorKey
}

enum NutritionColorKey: String, Equatable {
    case terra
    case sage
    case ocean
    case gold
    case plum
    case ink
}

struct Micronutrient: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let value: String
    let target: String
    let progress: Double
    let colorKey: NutritionColorKey
}

struct DailyNutrition: Equatable {
    var caloriesConsumed: Int
    var calorieTarget: Int
    var macros: [Macro]
    var micronutrients: [Micronutrient]

    var remainingCalories: Int {
        max(calorieTarget - caloriesConsumed, 0)
    }

    var calorieProgress: Double {
        min(Double(caloriesConsumed) / Double(calorieTarget), 1.2)
    }
}
