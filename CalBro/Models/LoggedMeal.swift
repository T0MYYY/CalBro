import Foundation

struct LoggedMeal: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let timestamp: Date
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let servingMultiplier: Double

    var adjustedCalories: Int { Int((Double(calories) * servingMultiplier).rounded()) }
    var adjustedProtein: Int  { Int((Double(proteinG)  * servingMultiplier).rounded()) }
    var adjustedCarbs: Int    { Int((Double(carbsG)    * servingMultiplier).rounded()) }
    var adjustedFat: Int      { Int((Double(fatG)      * servingMultiplier).rounded()) }

    var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f.string(from: timestamp)
    }
}
