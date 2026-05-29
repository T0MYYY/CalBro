import Foundation

enum CameraFlowState: Equatable {
    case scan
    case height
    case ready
    case recognizing
    case result
}

struct CameraHeightGuidance: Equatable {
    var currentCentimeters: Int
    var targetRange: ClosedRange<Int>
    var targetCentimeters: Int
    var directionLabel: String
    var isReady: Bool
    var tiltDegrees: Double
    var isTopDown: Bool

    var isCaptureReady: Bool {
        isReady && isTopDown && targetRange.contains(currentCentimeters)
    }

    static let captureReadyMock = CameraHeightGuidance(
        currentCentimeters: 30,
        targetRange: 27...33,
        targetCentimeters: 30,
        directionLabel: "Top-down locked",
        isReady: true,
        tiltDegrees: 3,
        isTopDown: true
    )
}

struct FoodRecognitionResult: Identifiable, Equatable {
    let id = UUID()
    let foodName: String
    let servingDescription: String
    var servingMultiplier: Double
    let confidence: Double
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    var modelFamily: String = "—"

    var adjustedCalories: Int {
        Int((Double(calories) * servingMultiplier).rounded())
    }
}
