import Foundation

enum PredictionScenario: String, CaseIterable, Identifiable, Codable {
    case gentle
    case current
    case aggressive

    var id: String { rawValue }

    var deficit: Int {
        switch self {
        case .gentle: 250
        case .current: 450
        case .aggressive: 700
        }
    }

    var label: String {
        "-\(deficit) kcal"
    }
}

struct WeightPredictionResult: Equatable, Codable {
    let targetDateLabel: String
    let summary: String
    let averageDeficit: Int
}

struct TDEEItem: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
    let progress: Double
    let colorKey: NutritionColorKey
}
