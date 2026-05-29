import Foundation

enum HealthMetricID: String, CaseIterable, Identifiable, Codable {
    case steps = "Steps"
    case activeCalories = "Active calories"
    case workouts = "Workouts"
    case sleep = "Sleep"
    case heartRate = "Heart rate"

    var id: String { rawValue }
}

struct HealthMetricSetting: Identifiable, Equatable, Codable {
    let id: HealthMetricID
    let subtitle: String
    var isEnabled: Bool
}

enum ReminderID: String, CaseIterable, Identifiable, Codable {
    case mealLogging = "Meal logging reminder"
    case calorieWarning = "Calorie warning"

    var id: String { rawValue }
}

struct ReminderSetting: Identifiable, Equatable, Codable {
    let id: ReminderID
    let detail: String
    var isEnabled: Bool
}

struct HealthSyncStatus: Equatable, Codable {
    var isConnected: Bool
    var statusText: String
}

struct WidgetPreviewModel: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let subtitle: String
}
