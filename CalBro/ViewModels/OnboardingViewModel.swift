import Foundation

enum OnboardingStep: Int, CaseIterable {
    case goal, body, activity, diet, result
}

@MainActor
@Observable
final class OnboardingViewModel {
    var step: OnboardingStep = .goal
    var profile = UserProfile()
    var isComplete = false

    private let stateStore: AppStateStore

    // Computed display values for result step (set after recalculate)
    private(set) var displayCalories: Int = 0
    private(set) var displayProtein: Int  = 0
    private(set) var displayCarbs: Int    = 0
    private(set) var displayFat: Int      = 0
    private(set) var displayBMR: Int      = 0
    private(set) var displayTDEE: Int     = 0
    private(set) var weeklyDeltaLabel: String = ""
    private(set) var goalTimelineLabel: String = ""

    init(stateStore: AppStateStore = UserDefaultsAppStateStore()) {
        self.stateStore = stateStore
        if let snapshot = stateStore.load(), snapshot.onboardingComplete {
            profile = snapshot.profile
            isComplete = true
            step = .result
        }
    }

    var progressText: String { "\(min(step.rawValue + 1, 4)) / 4" }

    var progress: Double {
        switch step {
        case .goal: 0.25
        case .body: 0.5
        case .activity: 0.75
        case .diet, .result: 1.0
        }
    }

    // MARK: - Input handlers

    func selectGoal(_ goal: FitnessGoal)      { profile.goal = goal }
    func selectSex(_ sex: BiologicalSex)       { profile.sex = sex }
    func adjustAge(by delta: Int)              { updateAge(profile.age + delta) }
    func updateAge(_ age: Int)                 { profile.age = min(max(age, 13), 99) }
    func updateHeight(_ cm: Int)               { profile.heightCentimeters = min(max(cm, 90), 240) }
    func updateWeight(_ kg: Int)               { profile.weightKilograms = min(max(kg, 30), 250) }
    func selectActivity(_ level: ActivityLevel){ profile.activityLevel = level }

    func toggleDietPreference(_ preference: DietPreference) {
        if preference == .noRestriction {
            profile.dietPreferences = [.noRestriction]; return
        }
        profile.dietPreferences.remove(.noRestriction)
        if profile.dietPreferences.contains(preference) {
            profile.dietPreferences.remove(preference)
        } else {
            profile.dietPreferences.insert(preference)
        }
        if profile.dietPreferences.isEmpty { profile.dietPreferences.insert(.noRestriction) }
    }

    // MARK: - Navigation

    func next() {
        switch step {
        case .goal:     step = .body
        case .body:     step = .activity
        case .activity: step = .diet
        case .diet:
            computeTargets()
            step = .result
        case .result:
            isComplete = true
            stateStore.save(AppStateSnapshot(onboardingComplete: true, profile: profile))
        }
    }

    func back() {
        switch step {
        case .goal:   break
        case .body:   step = .goal
        case .activity: step = .body
        case .diet:   step = .activity
        case .result: step = .diet
        }
    }

    func skipDiet() {
        profile.dietPreferences = [.noRestriction]
        computeTargets()
        step = .result
    }

    // MARK: - Computation

    private func computeTargets() {
        profile.recalculateTargets()
        displayBMR      = profile.bmr
        displayTDEE     = profile.tdee
        displayCalories = profile.calorieTarget
        displayProtein  = profile.proteinTargetG
        displayCarbs    = profile.carbTargetG
        displayFat      = profile.fatTargetG

        let weeklyKg = abs(profile.weeklyWeightChangeKg)
        if weeklyKg > 0.01 {
            let direction = profile.goal.dailyAdjustment < 0 ? "Lose" : "Gain"
            weeklyDeltaLabel  = "\(direction) ~\(String(format: "%.1f", weeklyKg)) kg/week"
            goalTimelineLabel = "Consistent tracking gets results"
        } else {
            weeklyDeltaLabel  = "Maintenance mode"
            goalTimelineLabel = "Focus on quality and consistency"
        }
    }
}
