import Foundation
import UserNotifications

protocol ReminderService: Sendable {
    func updateReminder(_ reminder: ReminderSetting) async -> ReminderSetting
}

final class MockReminderService: ReminderService {
    func updateReminder(_ reminder: ReminderSetting) async -> ReminderSetting {
        reminder
    }
}

// MARK: - Real local-notification backed reminders

final class RealReminderService: ReminderService, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    static let mealLoggingID = "calbro.reminder.mealLogging"
    /// Persisted so MealLogStore can decide whether to fire the threshold alert.
    static let calorieWarningEnabledKey = "calBuddy.reminder.calorieWarning.enabled"

    func updateReminder(_ reminder: ReminderSetting) async -> ReminderSetting {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else {
            // Permission denied — reflect the off state back to the UI.
            var off = reminder
            off.isEnabled = false
            return off
        }

        switch reminder.id {
        case .mealLogging:
            if reminder.isEnabled { scheduleDailyMealReminder() }
            else { center.removePendingNotificationRequests(withIdentifiers: [Self.mealLoggingID]) }
        case .calorieWarning:
            UserDefaults.standard.set(reminder.isEnabled, forKey: Self.calorieWarningEnabledKey)
        }
        return reminder
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    private func scheduleDailyMealReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Log your meals"
        content.body = "Don't forget to track what you've eaten today."
        content.sound = .default

        var components = DateComponents()
        components.hour = 12
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.mealLoggingID, content: content, trigger: trigger)
        center.add(request)
    }
}

// MARK: - Calorie warning (event-driven, fired by MealLogStore)

enum CalorieWarningNotifier {
    private static let lastFiredDayKey = "calBuddy.reminder.calorieWarning.lastFiredDay"
    private static let identifier = "calbro.reminder.calorieWarning"

    /// Fires once per day when consumption first crosses 90% of the target.
    static func evaluate(consumed: Int, target: Int) {
        guard UserDefaults.standard.bool(forKey: RealReminderService.calorieWarningEnabledKey),
              target > 0,
              Double(consumed) >= Double(target) * 0.90
        else { return }

        let today = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: lastFiredDayKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return  // already fired today
        }
        UserDefaults.standard.set(today, forKey: lastFiredDayKey)

        let content = UNMutableNotificationContent()
        content.title = "Calorie budget almost reached"
        content.body = "You've used \(consumed) of \(target) kcal today (\(Int(Double(consumed) / Double(target) * 100))%)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
