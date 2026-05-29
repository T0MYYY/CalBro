import Foundation

@MainActor
@Observable
final class GoalsViewModel {
    var profile: UserProfile
    var selectedScenario: PredictionScenario? = .current
    var prediction: WeightPredictionResult?
    var deficit: Double

    private let predictionService: PredictionService
    private let defaults: UserDefaults
    private let persistenceKey: String

    private struct PersistedState: Codable {
        var selectedScenario: PredictionScenario?
        var prediction: WeightPredictionResult?
        var deficit: Double
    }

    init(
        profile: UserProfile = UserProfile(),
        predictionService: PredictionService = RealPredictionService(),
        defaults: UserDefaults = .standard,
        persistenceKey: String = "calBuddy.goals.v1"
    ) {
        self.profile = profile
        self.predictionService = predictionService
        self.defaults = defaults
        self.persistenceKey = persistenceKey
        self.deficit = Double(abs(profile.goal.dailyAdjustment))
        restore()
        if prediction == nil {
            prediction = WeightPredictionResult(
                targetDateLabel: "—",
                summary: "Update your profile to see your projection",
                averageDeficit: abs(profile.goal.dailyAdjustment)
            )
        }
    }

    // MARK: - Real TDEE breakdown

    var tdeeItems: [TDEEItem] {
        let bmr  = profile.bmr
        let tdee = profile.tdee
        let adj  = profile.goal.dailyAdjustment
        let goal = profile.calorieTarget
        return [
            TDEEItem(label: "BMR (base metabolism)",
                     value: "\(bmr.formatted()) kcal",
                     progress: Double(bmr) / Double(tdee),
                     colorKey: .ink),
            TDEEItem(label: "Activity ×\(String(format: "%.3g", profile.activityLevel.multiplier))",
                     value: "+\((tdee - bmr).formatted()) kcal",
                     progress: Double(tdee - bmr) / Double(tdee),
                     colorKey: .ink),
            TDEEItem(label: "TDEE total",
                     value: "\(tdee.formatted()) kcal",
                     progress: 1.0,
                     colorKey: .sage),
            TDEEItem(label: adj < 0 ? "Daily deficit" : "Daily surplus",
                     value: "\(adj < 0 ? "-" : "+")\(abs(adj)) kcal",
                     progress: Double(abs(adj)) / Double(tdee),
                     colorKey: .ink),
            TDEEItem(label: "Your calorie goal",
                     value: "\(goal.formatted()) kcal",
                     progress: Double(goal) / Double(tdee),
                     colorKey: .terra)
        ]
    }

    // MARK: - Actions

    func selectScenario(_ scenario: PredictionScenario) async {
        selectedScenario = scenario
        deficit = Double(scenario.deficit)
        prediction = await predictionService.prediction(for: scenario, profile: profile)
        persist()
    }

    func updateDeficit(_ value: Double) async {
        deficit = value
        selectedScenario = nil
        prediction = await predictionService.prediction(forDeficit: Int(value.rounded()), profile: profile)
        persist()
    }

    func refreshWithProfile(_ newProfile: UserProfile) async {
        profile = newProfile
        prediction = await predictionService.prediction(forDeficit: Int(deficit), profile: profile)
        persist()
    }

    // MARK: - Profile refresh (call after editing profile)

    func refreshFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return }
        profile = snap.profile
        deficit = Double(abs(profile.goal.dailyAdjustment))
    }

    // MARK: - Persistence

    private func restore() {
        guard let data = defaults.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }
        selectedScenario = state.selectedScenario
        prediction = state.prediction
        deficit = state.deficit
    }

    private func persist() {
        let state = PersistedState(selectedScenario: selectedScenario, prediction: prediction, deficit: deficit)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}
