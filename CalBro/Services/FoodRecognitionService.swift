import Foundation

protocol FoodRecognitionService: Sendable {
    func recognizeFood(from imageData: Data?, guidance: CameraHeightGuidance) async throws -> FoodRecognitionResult
}

// Mock — used in tests and simulator
final class MockFoodRecognitionService: FoodRecognitionService {
    func recognizeFood(from imageData: Data?, guidance: CameraHeightGuidance) async throws -> FoodRecognitionResult {
        try await Task.sleep(for: .milliseconds(400))
        return FoodRecognitionResult(
            foodName: "Mixed bowl",
            servingDescription: "1 serving · ~320g",
            servingMultiplier: 1.0,
            confidence: 0.91,
            calories: 520,
            protein: 32,
            carbs: 68,
            fat: 14
        )
    }
}

// Real — delegates to CoreML pipeline
final class DPFFoodRecognitionService: FoodRecognitionService {
    private let prediction: NutritionPredictionService

    init(prediction: NutritionPredictionService = CoreMLNutritionPredictionService()) {
        self.prediction = prediction
    }

    func recognizeFood(from imageData: Data?, guidance: CameraHeightGuidance) async throws -> FoodRecognitionResult {
        let data = imageData ?? Data()
        let p = try await prediction.predictNutrition(from: data, guidance: guidance)
        return FoodRecognitionResult(
            foodName: p.foodName,
            servingDescription: p.servingDescription,
            servingMultiplier: 1.0,
            confidence: p.confidence,
            calories: p.calories,
            protein: p.protein,
            carbs: p.carbs,
            fat: p.fat,
            modelFamily: p.modelFamily
        )
    }
}
