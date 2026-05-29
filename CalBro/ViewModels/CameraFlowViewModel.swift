import Foundation
import UIKit

enum CapturePhase: Equatable {
    case scanning          // waiting for overhead + correct height
    case aiming            // locked — filling progress ring
    case countdown(Int)    // 3 → 2 → 1
    case processing
    case result
}

@MainActor
@Observable
final class CameraFlowViewModel {
    private(set) var phase: CapturePhase = .scanning
    private(set) var tiltDegrees: Double = 45.0
    private(set) var aimingProgress: Double = 0.0
    /// Measured height above surface in cm (nil = depth unavailable on this device)
    private(set) var heightCm: Double? = nil

    var result: FoodRecognitionResult?
    var capturedImageData: Data?
    var errorMessage: String?

    private let motionService = CMMotionMeasurementService()
    private let recognitionService: FoodRecognitionService
    private let mealStore: MealLogStore

    private var countdownTask: Task<Void, Never>?

    /// Tilt angle threshold for overhead detection (degrees from straight-down)
    static let overheadThreshold: Double = 28
    /// Acceptable height range for capture (cm) — tight 27–34 cm band to match DPF training distribution
    static let heightRange: ClosedRange<Double> = 27...34

    init(
        recognitionService: FoodRecognitionService? = nil,
        mealStore: MealLogStore = .shared
    ) {
        #if targetEnvironment(simulator)
        self.recognitionService = recognitionService ?? MockFoodRecognitionService()
        #else
        self.recognitionService = recognitionService ?? DPFFoodRecognitionService()
        #endif
        self.mealStore = mealStore
    }

    // MARK: - Ready check

    /// True when both tilt AND height (if available) are within acceptable range.
    var isReadyToAim: Bool {
        guard tiltDegrees < Self.overheadThreshold else { return false }
        if let h = heightCm {
            return Self.heightRange.contains(h)
        }
        return true   // no depth sensor — gate on tilt only
    }

    /// True during countdown if phone has moved too far out of alignment.
    private var countdownShouldCancel: Bool {
        if tiltDegrees > Self.overheadThreshold + 15 { return true }
        // Cancel if height drifts outside a relaxed range during countdown
        if let h = heightCm, (h < 22 || h > 40) { return true }
        return false
    }

    // MARK: - Main guidance loop

    func run(camera: CameraCaptureController) async {
        while !Task.isCancelled {
            let g = await motionService.currentGuidance()
            tiltDegrees = g.tiltDegrees
            heightCm = camera.currentHeightCm

            switch phase {
            case .scanning:
                if isReadyToAim { enterAiming(camera: camera) }

            case .aiming:
                if !isReadyToAim {
                    cancelCountdown()
                    aimingProgress = 0
                    phase = .scanning
                }

            case .countdown:
                if countdownShouldCancel {
                    cancelCountdown()
                    aimingProgress = 0
                    phase = .scanning
                }

            case .processing, .result:
                break
            }

            do { try await Task.sleep(for: .milliseconds(200)) }
            catch { return }
        }
    }

    // MARK: - Manual shutter

    func manualCapture(camera: CameraCaptureController) {
        guard phase == .scanning || phase == .aiming else { return }
        cancelCountdown()
        Task { await doCapture(camera: camera) }
    }

    // MARK: - Result actions

    func addToLog(multiplier: Double) {
        guard let r = result else { return }
        mealStore.log(LoggedMeal(
            id: UUID(), name: r.foodName, timestamp: Date(),
            calories: r.calories, proteinG: r.protein,
            carbsG: r.carbs, fatG: r.fat,
            servingMultiplier: multiplier
        ))
        reset()
    }

    func dismissResult() { reset() }

    // MARK: - Private

    private func enterAiming(camera: CameraCaptureController) {
        guard phase == .scanning else { return }
        phase = .aiming
        aimingProgress = 0
        countdownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 50
            for i in 0...steps {
                guard !Task.isCancelled else { return }
                self.aimingProgress = Double(i) / Double(steps)
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled, self.phase == .aiming else { return }
            for n in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                self.phase = .countdown(n)
                UIImpactFeedbackGenerator(style: n == 1 ? .heavy : .medium).impactOccurred()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            await self.doCapture(camera: camera)
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func doCapture(camera: CameraCaptureController) async {
        phase = .processing
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let imageData: Data? = camera.status.canCapture
            ? (try? await camera.capturePhotoData()) : nil
        capturedImageData = imageData
        do {
            result = try await recognitionService.recognizeFood(from: imageData,
                                                                guidance: .captureReadyMock)
            phase = .result
        } catch {
            errorMessage = "Recognition failed"
            phase = .scanning
        }
    }

    private func reset() {
        cancelCountdown()
        phase = .scanning
        aimingProgress = 0
        result = nil
        capturedImageData = nil
        errorMessage = nil
    }
}
