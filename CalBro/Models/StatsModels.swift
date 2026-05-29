import Foundation

struct TrendBar: Identifiable, Equatable {
    let id = UUID()
    let day: String
    let valueLabel: String
    let progress: Double
    let isToday: Bool
}
