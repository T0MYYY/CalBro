import Foundation

enum FitnessGoal: String, CaseIterable, Identifiable, Codable {
    case loseFat         = "Lose fat\n& tone"
    case buildMuscle     = "Build\nmuscle"
    case gainWeight      = "Gain\nweight"
    case maintain        = "Maintain\nweight"
    case betterNutrition = "Better\nnutrition"
    case healthCondition = "Health\ncondition"

    var id: String { rawValue }
    var title: String { rawValue.replacingOccurrences(of: "\n", with: " ") }

    // kcal delta applied to TDEE
    var dailyAdjustment: Int {
        switch self {
        case .loseFat:         return -500
        case .buildMuscle:     return  300
        case .gainWeight:      return  500
        case .maintain:        return    0
        case .betterNutrition: return    0
        case .healthCondition: return -200
        }
    }
}

enum BiologicalSex: String, CaseIterable, Identifiable, Codable {
    case male   = "Male"
    case female = "Female"
    case other  = "Other"
    var id: String { rawValue }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary        = "Sedentary"
    case lightlyActive    = "Lightly active"
    case moderatelyActive = "Moderately active"
    case veryActive       = "Very active"
    case athlete          = "Athlete"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary:        return 1.200
        case .lightlyActive:    return 1.375
        case .moderatelyActive: return 1.550
        case .veryActive:       return 1.725
        case .athlete:          return 1.900
        }
    }

    var multiplierLabel: String {
        switch self {
        case .sedentary:        return "x1.2"
        case .lightlyActive:    return "x1.375"
        case .moderatelyActive: return "x1.55"
        case .veryActive:       return "x1.725"
        case .athlete:          return "x1.9"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary:        return "Desk job, little exercise"
        case .lightlyActive:    return "1-3 workouts / week"
        case .moderatelyActive: return "3-5 workouts / week"
        case .veryActive:       return "6-7 intense workouts / week"
        case .athlete:          return "Twice daily / physical job"
        }
    }
}

enum DietPreference: String, CaseIterable, Identifiable, Codable {
    case noRestriction = "No restriction"
    case vegetarian    = "Vegetarian"
    case vegan         = "Vegan"
    case lowCarb       = "Low-carb"
    case keto          = "Keto"
    case highProtein   = "High-protein"
    case glutenFree    = "Gluten-free"
    case dairyFree     = "Dairy-free"

    var id: String { rawValue }
    var displayLabel: String { rawValue }
}

enum UnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric   = "Metric"
    case imperial = "Imperial"
    var id: String { rawValue }
}

struct UserProfile: Equatable, Codable {
    var goal: FitnessGoal      = .loseFat
    var sex: BiologicalSex     = .male
    var age: Int               = 28
    var heightCentimeters: Int = 172
    var weightKilograms: Int   = 74
    var activityLevel: ActivityLevel = .lightlyActive
    var dietPreferences: Set<DietPreference> = [.noRestriction, .glutenFree]
    /// Display preference for height & weight. Calories are always shown in kcal.
    var units: UnitSystem = .metric

    // MARK: - Unit-aware display (calories never converted)

    var heightDisplay: String {
        switch units {
        case .metric:
            return "\(heightCentimeters) cm"
        case .imperial:
            let totalInches = Int((Double(heightCentimeters) / 2.54).rounded())
            return "\(totalInches / 12)′\(totalInches % 12)″"
        }
    }

    var weightDisplay: String {
        switch units {
        case .metric:   return "\(weightKilograms) kg"
        case .imperial: return "\(Int((Double(weightKilograms) * 2.20462).rounded())) lb"
        }
    }

    /// Formats a weekly weight change (stored in kg) in the user's preferred unit.
    func weightRateDisplay(kgPerWeek: Double) -> String {
        switch units {
        case .metric:   return String(format: "%.1f kg/week", kgPerWeek)
        case .imperial: return String(format: "%.1f lb/week", kgPerWeek * 2.20462)
        }
    }

    // Stored after onboarding computation
    var calorieTarget:  Int = 1820
    var proteinTargetG: Int = 150
    var carbTargetG:    Int = 180
    var fatTargetG:     Int = 60

    // Mifflin-St Jeor BMR
    var bmr: Int {
        let w = Double(weightKilograms)
        let h = Double(heightCentimeters)
        let a = Double(age)
        let base = 10 * w + 6.25 * h - 5 * a
        switch sex {
        case .male:   return Int((base + 5).rounded())
        case .female: return Int((base - 161).rounded())
        case .other:  return Int((base - 78).rounded())
        }
    }

    var tdee: Int { Int((Double(bmr) * activityLevel.multiplier).rounded()) }

    var weeklyWeightChangeKg: Double {
        let daily = Double(goal.dailyAdjustment)
        return (daily * 7) / 7700  // 7700 kcal ≈ 1 kg body weight
    }

    mutating func recalculateTargets() {
        calorieTarget = max(1000, tdee + goal.dailyAdjustment)
        let kcal = Double(calorieTarget)

        switch goal {
        case .loseFat:
            proteinTargetG = Int((Double(weightKilograms) * 2.2).rounded())
            fatTargetG     = Int((kcal * 0.25 / 9).rounded())
        case .buildMuscle:
            proteinTargetG = Int((Double(weightKilograms) * 2.0).rounded())
            fatTargetG     = Int((kcal * 0.28 / 9).rounded())
        case .gainWeight:
            proteinTargetG = Int((Double(weightKilograms) * 1.8).rounded())
            fatTargetG     = Int((kcal * 0.30 / 9).rounded())
        default:
            proteinTargetG = Int((Double(weightKilograms) * 1.6).rounded())
            fatTargetG     = Int((kcal * 0.30 / 9).rounded())
        }
        proteinTargetG = max(40, proteinTargetG)
        fatTargetG     = max(20, fatTargetG)
        let proteinKcal = Double(proteinTargetG) * 4
        let fatKcal     = Double(fatTargetG) * 9
        carbTargetG     = max(30, Int(((kcal - proteinKcal - fatKcal) / 4).rounded()))
    }
}
