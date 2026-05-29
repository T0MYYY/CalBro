import Foundation

struct NutritionPrediction: Equatable, Codable {
    var foodName: String
    var servingDescription: String
    var confidence: Double
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var modelFamily: String
}

enum NutritionPredictionError: Error, Equatable {
    case modelUnavailable
    case captureGuidanceNotReady
}
