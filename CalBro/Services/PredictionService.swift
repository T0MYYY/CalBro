import Foundation

protocol PredictionService: Sendable {
    func prediction(for scenario: PredictionScenario, profile: UserProfile) async -> WeightPredictionResult
    func prediction(forDeficit deficit: Int, profile: UserProfile) async -> WeightPredictionResult
}

// Real weight projection using 7700 kcal/kg rule + metabolic adaptation factor
final class RealPredictionService: PredictionService {
    func prediction(for scenario: PredictionScenario, profile: UserProfile) async -> WeightPredictionResult {
        await prediction(forDeficit: scenario.deficit, profile: profile)
    }

    func prediction(forDeficit deficit: Int, profile: UserProfile) async -> WeightPredictionResult {
        let clamped = Double(min(max(deficit, 50), 1000))
        // 7700 kcal ≈ 1 kg; account for metabolic adaptation (95% efficiency after 4 weeks)
        let weeklyKg = (clamped * 7) / 7700 * 0.92
        let adjustment = profile.goal.dailyAdjustment < 0 ? -10.0 : 5.0
        let targetWeight = max(Double(profile.weightKilograms) * 0.85,
                               Double(profile.weightKilograms) + adjustment)
        let deltaKg = abs(Double(profile.weightKilograms) - targetWeight)
        let weeksNeeded = deltaKg / max(weeklyKg, 0.01)

        let targetDate = Calendar.current.date(byAdding: .day, value: Int(weeksNeeded * 7), to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let dateLabel = formatter.string(from: targetDate)

        let targetKg = Int(targetWeight.rounded())
        let direction = deficit > 0 ? "Reach" : "Add"
        return WeightPredictionResult(
            targetDateLabel: dateLabel,
            summary: "\(direction) \(targetKg) kg by \(dateLabel)",
            averageDeficit: Int(clamped)
        )
    }
}

// Kept for test compatibility
final class MockPredictionService: PredictionService {
    private let real = RealPredictionService()
    func prediction(for scenario: PredictionScenario, profile: UserProfile) async -> WeightPredictionResult {
        await real.prediction(for: scenario, profile: profile)
    }
    func prediction(forDeficit deficit: Int, profile: UserProfile) async -> WeightPredictionResult {
        await real.prediction(forDeficit: deficit, profile: profile)
    }
}
