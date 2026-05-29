import Foundation

@MainActor
@Observable
final class IntegrationViewModel {
    var healthConnected = false
    var healthStatusText = "Not connected"
    var healthMetrics: [HealthMetricSetting] = [
        HealthMetricSetting(id: .steps, subtitle: "Adds to active calorie burn", isEnabled: true),
        HealthMetricSetting(id: .activeCalories, subtitle: "Updates TDEE in real time", isEnabled: true),
        HealthMetricSetting(id: .workouts, subtitle: "Auto-logged to your diary", isEnabled: true),
        HealthMetricSetting(id: .sleep, subtitle: "Affects recovery & hunger est.", isEnabled: false),
        HealthMetricSetting(id: .heartRate, subtitle: "Resting HR helps refine BMR", isEnabled: false)
    ]
    var reminders: [ReminderSetting] = [
        ReminderSetting(id: .mealLogging, detail: "Daily at 12:00", isEnabled: true),
        ReminderSetting(id: .calorieWarning, detail: "Alert at 90% used", isEnabled: false)
    ]
    var widgets: [WidgetPreviewModel] = []

    private let healthService: HealthKitSyncService
    private let reminderService: ReminderService
    private let widgetService: WidgetPreviewService
    private let defaults: UserDefaults
    private let persistenceKey: String

    private struct PersistedState: Codable {
        var healthConnected: Bool
        var healthStatusText: String
        var healthMetrics: [HealthMetricSetting]
        var reminders: [ReminderSetting]
    }

    init(
        healthService: HealthKitSyncService? = nil,
        reminderService: ReminderService? = nil,
        widgetService: WidgetPreviewService = MockWidgetPreviewService(),
        defaults: UserDefaults = .standard,
        persistenceKey: String = "calBuddy.integrations.v1"
    ) {
        #if targetEnvironment(simulator)
        let healthService = healthService ?? MockHealthKitSyncService()
        let reminderService = reminderService ?? MockReminderService()
        #else
        let healthService = healthService ?? RealHealthKitSyncService()
        let reminderService = reminderService ?? RealReminderService()
        #endif
        self.healthService = healthService
        self.reminderService = reminderService
        self.widgetService = widgetService
        self.defaults = defaults
        self.persistenceKey = persistenceKey
        widgets = [
            WidgetPreviewModel(id: "lock-calories", title: "Calories", subtitle: "1,240 of 1,820 kcal"),
            WidgetPreviewModel(id: "home-medium", title: "Today", subtitle: "560 kcal left")
        ]
        restore()
    }

    func toggleHealthConnected() async {
        let status = await healthService.setConnected(!healthConnected)
        healthConnected = status.isConnected
        healthStatusText = status.statusText
        persist()
    }

    func toggleMetric(_ id: HealthMetricID) {
        guard let index = healthMetrics.firstIndex(where: { $0.id == id }) else { return }
        healthMetrics[index].isEnabled.toggle()
        persist()
    }

    func toggleReminder(_ id: ReminderID) async {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].isEnabled.toggle()
        reminders[index] = await reminderService.updateReminder(reminders[index])
        persist()
    }

    func refreshWidgets() async {
        widgets = await widgetService.previews()
    }

    private func restore() {
        guard let data = defaults.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }
        healthConnected = state.healthConnected
        healthStatusText = state.healthStatusText
        healthMetrics = state.healthMetrics
        reminders = state.reminders
    }

    private func persist() {
        let state = PersistedState(
            healthConnected: healthConnected,
            healthStatusText: healthStatusText,
            healthMetrics: healthMetrics,
            reminders: reminders
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}
