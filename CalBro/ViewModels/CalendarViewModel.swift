import Foundation

/// One grid cell. `id` is the cell's position in the month grid so padding cells
/// stay stable across recomputations (avoids SwiftUI index-out-of-range crashes).
struct CalendarDayModel: Identifiable, Equatable {
    let id: Int
    let day: Int?
    let status: NutritionColorKey?
    let isToday: Bool
}

@MainActor
@Observable
final class CalendarViewModel {
    /// First moment of the displayed month.
    private(set) var monthAnchor: Date
    var selectedDay: Int?

    private let mealStore: MealLogStore
    private let calendar = Calendar.current

    init(mealStore: MealLogStore = .shared) {
        self.mealStore = mealStore
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        self.monthAnchor = Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - Derived state

    var monthTitle: String {
        monthAnchor.formatted(.dateTime.month(.wide).year())
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }

    private var calorieTarget: Int {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return UserProfile().calorieTarget }
        return snap.profile.calorieTarget
    }

    /// Grid of weeks (each 7 cells). Computed from real logged meals.
    var weeks: [[CalendarDayModel]] {
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthAnchor)
        let mondayOffset = (firstWeekday + 5) % 7
        let todayDay = isCurrentMonth ? calendar.component(.day, from: Date()) : nil

        var cells: [CalendarDayModel] = []
        var idx = 0
        for _ in 0..<mondayOffset {
            cells.append(CalendarDayModel(id: idx, day: nil, status: nil, isToday: false)); idx += 1
        }
        for day in range {
            cells.append(CalendarDayModel(id: idx, day: day, status: status(forDay: day), isToday: day == todayDay))
            idx += 1
        }
        while cells.count % 7 != 0 {
            cells.append(CalendarDayModel(id: idx, day: nil, status: nil, isToday: false)); idx += 1
        }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// Real monthly summary computed from logged meals.
    var summary: (onTarget: Int, over: Int, missed: Int) {
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor) else { return (0, 0, 0) }
        let today = calendar.startOfDay(for: Date())
        let target = calorieTarget
        var onTarget = 0, over = 0, missed = 0
        for day in range {
            guard let date = date(forDay: day) else { continue }
            let start = calendar.startOfDay(for: date)
            if start > today { continue }  // future days don't count
            let consumed = consumedCalories(on: start)
            if consumed == 0 { missed += 1 }
            else if consumed > Int(Double(target) * 1.10) { over += 1 }
            else { onTarget += 1 }
        }
        return (onTarget, over, missed)
    }

    func status(forDay day: Int) -> NutritionColorKey? {
        guard let date = date(forDay: day) else { return nil }
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        if start > today { return nil }                 // future — empty
        let consumed = consumedCalories(on: start)
        if consumed == 0 { return nil }                 // no log
        return consumed > Int(Double(calorieTarget) * 1.10) ? .terra : .sage
    }

    // MARK: - Actions

    func select(day: Int) { selectedDay = day }
    func nextMonth() { shiftMonth(by: 1) }
    func previousMonth() { shiftMonth(by: -1) }

    func handleMonthSwipe(width: Double, height: Double, startX: Double) {
        guard startX > 36 else { return }  // leave the left edge for back-swipe
        guard abs(width) > 72, abs(width) > abs(height) * 1.6 else { return }
        if width < 0 { nextMonth() } else { previousMonth() }
    }

    // MARK: - Helpers

    private func shiftMonth(by amount: Int) {
        guard let next = calendar.date(byAdding: .month, value: amount, to: monthAnchor) else { return }
        monthAnchor = next
        selectedDay = nil
    }

    private func date(forDay day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: monthAnchor)
        comps.day = day
        return calendar.date(from: comps)
    }

    private func consumedCalories(on dayStart: Date) -> Int {
        mealStore.meals
            .filter { calendar.isDate($0.timestamp, inSameDayAs: dayStart) }
            .reduce(0) { $0 + $1.adjustedCalories }
    }
}
