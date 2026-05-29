import XCTest
@testable import CalBro

@MainActor
final class CalBroStateTests: XCTestCase {
    private final class SpyFoodRecognitionService: FoodRecognitionService, @unchecked Sendable {
        var receivedBytes = 0

        func recognizeFood(from imageData: Data?, guidance: CameraHeightGuidance) async throws -> FoodRecognitionResult {
            receivedBytes = imageData?.count ?? 0
            return FoodRecognitionResult(
                foodName: "Captured Meal",
                servingDescription: "camera capture",
                servingMultiplier: 1,
                confidence: 0.91,
                calories: 315,
                protein: 20,
                carbs: 30,
                fat: 11
            )
        }
    }

    private func makeStore(name: String = UUID().uuidString) -> UserDefaultsAppStateStore {
        let defaults = UserDefaults(suiteName: "CalBroTests.\(name)")!
        defaults.removePersistentDomain(forName: "CalBroTests.\(name)")
        return UserDefaultsAppStateStore(defaults: defaults)
    }

    private func makeDefaults(name: String = UUID().uuidString) -> UserDefaults {
        let suiteName = "CalBroTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testOnboardingCompletesAfterTargetResult() {
        let model = OnboardingViewModel(stateStore: makeStore())

        XCTAssertEqual(model.step, .goal)
        model.selectGoal(.buildMuscle)
        model.next()
        model.next()
        model.next()
        model.next()
        XCTAssertEqual(model.step, .result)
        XCTAssertFalse(model.isComplete)

        model.next()

        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.profile.goal, .buildMuscle)
    }

    func testOnboardingBodyStatsCanBeEditedDirectly() {
        let model = OnboardingViewModel(stateStore: makeStore())

        model.updateAge(41)
        model.updateHeight(181)
        model.updateWeight(82)

        XCTAssertEqual(model.profile.age, 41)
        XCTAssertEqual(model.profile.heightCentimeters, 181)
        XCTAssertEqual(model.profile.weightKilograms, 82)
    }

    func testDietPreferenceLabelDoesNotChangeWhenSelected() {
        XCTAssertEqual(DietPreference.vegan.displayLabel, "Vegan")
        XCTAssertEqual(DietPreference.vegan.displayLabel, DietPreference.vegan.rawValue)
    }

    func testOnboardingStatePersistsAfterCompletion() {
        let store = makeStore()
        let first = OnboardingViewModel(stateStore: store)

        first.selectGoal(.betterNutrition)
        first.updateAge(36)
        first.updateHeight(179)
        first.updateWeight(86)
        first.selectActivity(.veryActive)
        first.next()
        first.next()
        first.next()
        first.next()
        first.next()

        let restored = OnboardingViewModel(stateStore: store)

        XCTAssertTrue(restored.isComplete)
        XCTAssertEqual(restored.profile.goal, .betterNutrition)
        XCTAssertEqual(restored.profile.age, 36)
        XCTAssertEqual(restored.profile.heightCentimeters, 179)
        XCTAssertEqual(restored.profile.weightKilograms, 86)
        XCTAssertEqual(restored.profile.activityLevel, .veryActive)
    }

    func testVisibleTabsExcludeLogShortcut() {
        XCTAssertEqual(AppTab.visibleTabs, [.today, .stats, .profile])
    }

    func testCameraCaptureProducesMockRecognitionResult() async throws {
        let model = CameraFlowViewModel(foodRecognitionService: MockFoodRecognitionService())

        XCTAssertEqual(model.state, .scan)
        model.advance()
        model.advance()
        XCTAssertEqual(model.state, .ready)

        try await model.capture()

        XCTAssertEqual(model.state, .result)
        XCTAssertEqual(model.recognitionResult?.foodName, "Oatmeal Bowl")
        XCTAssertEqual(model.recognitionResult?.calories, 420)
    }

    func testCameraCaptureUsesCapturedImageData() async throws {
        let service = SpyFoodRecognitionService()
        let model = CameraFlowViewModel(foodRecognitionService: service)
        let imageData = Data([1, 2, 3, 4, 5])

        model.advance()
        model.advance()
        try await model.capture(imageData: imageData)

        XCTAssertEqual(service.receivedBytes, imageData.count)
        XCTAssertEqual(model.capturedImageData, imageData)
        XCTAssertEqual(model.recognitionResult?.foodName, "Captured Meal")
    }

    func testCalendarSelectionAndMonthNavigationAreLocal() {
        let model = CalendarViewModel()

        XCTAssertEqual(model.displayedMonth.month, 5)
        model.select(day: 18)
        XCTAssertEqual(model.selectedDay, 18)
        model.nextMonth()
        XCTAssertEqual(model.displayedMonth.month, 6)
        XCTAssertNil(model.selectedDay)
        model.previousMonth()
        XCTAssertEqual(model.displayedMonth.month, 5)
    }

    func testCalendarSwipeChangesMonthWithoutHijackingBackSwipe() {
        let model = CalendarViewModel()

        model.handleMonthSwipe(width: -120, height: 8, startX: 140)
        XCTAssertEqual(model.displayedMonth.month, 6)

        model.handleMonthSwipe(width: 120, height: 4, startX: 140)
        XCTAssertEqual(model.displayedMonth.month, 5)

        model.handleMonthSwipe(width: 130, height: 0, startX: 16)
        XCTAssertEqual(model.displayedMonth.month, 5)
    }

    func testARGuidanceRequiresTopDownAndDistance() async {
        let service = MockARMeasurementService()
        let guidance = await service.currentGuidance()

        XCTAssertTrue(guidance.isCaptureReady)
        XCTAssertTrue(guidance.isTopDown)
        XCTAssertEqual(guidance.targetCentimeters, 30)
    }

    func testNutritionPredictionMockProducesBackboneResult() async throws {
        let service = MockNutritionPredictionService()

        let prediction = try await service.predictNutrition(from: Data(), guidance: .captureReadyMock)

        XCTAssertEqual(prediction.foodName, "Oatmeal Bowl")
        XCTAssertEqual(prediction.calories, 420)
        XCTAssertEqual(prediction.modelFamily, "DPF Food2K + Depth Anything V2")
    }

    func testIntegrationTogglesStayMockedLocally() async {
        let model = IntegrationViewModel(
            healthService: MockHealthKitSyncService(),
            reminderService: MockReminderService(),
            widgetService: MockWidgetPreviewService(),
            defaults: makeDefaults()
        )

        XCTAssertTrue(model.healthConnected)
        await model.toggleHealthConnected()
        XCTAssertFalse(model.healthConnected)

        model.toggleMetric(.steps)
        XCTAssertFalse(model.healthMetrics.first { $0.id == .steps }?.isEnabled ?? true)

        await model.toggleReminder(.mealLogging)
        XCTAssertFalse(model.reminders.first { $0.id == .mealLogging }?.isEnabled ?? true)
    }

    func testIntegrationTogglesPersistAcrossViewModels() async {
        let defaults = makeDefaults()
        let first = IntegrationViewModel(defaults: defaults)

        first.toggleMetric(.sleep)
        await first.toggleReminder(.calorieWarning)

        let restored = IntegrationViewModel(defaults: defaults)

        XCTAssertTrue(restored.healthMetrics.first { $0.id == .sleep }?.isEnabled ?? false)
        XCTAssertTrue(restored.reminders.first { $0.id == .calorieWarning }?.isEnabled ?? false)
    }

    func testPredictionScenarioUpdatesMockResult() async {
        let model = GoalsViewModel(predictionService: MockPredictionService(), defaults: makeDefaults())

        XCTAssertEqual(model.selectedScenario?.deficit, 450)
        await model.selectScenario(.aggressive)

        XCTAssertEqual(model.selectedScenario, .aggressive)
        XCTAssertEqual(model.prediction?.targetDateLabel, "Jul 2026")
    }

    func testPredictionDeficitSliderSupportsCustomValues() async {
        let model = GoalsViewModel(predictionService: MockPredictionService(), defaults: makeDefaults())

        await model.updateDeficit(525)

        XCTAssertEqual(model.deficit, 525)
        XCTAssertNil(model.selectedScenario)
        XCTAssertEqual(model.prediction?.averageDeficit, 525)
    }

    func testPredictionStatePersistsAcrossViewModels() async {
        let defaults = makeDefaults()
        let first = GoalsViewModel(predictionService: MockPredictionService(), defaults: defaults)

        await first.updateDeficit(525)

        let restored = GoalsViewModel(predictionService: MockPredictionService(), defaults: defaults)

        XCTAssertEqual(restored.deficit, 525)
        XCTAssertNil(restored.selectedScenario)
        XCTAssertEqual(restored.prediction?.averageDeficit, 525)
    }
}
