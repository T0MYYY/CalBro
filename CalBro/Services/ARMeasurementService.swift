import Foundation
import CoreMotion
#if canImport(ARKit)
import ARKit
#endif

protocol ARMeasurementService: Sendable {
    func currentGuidance() async -> CameraHeightGuidance
}

// Simulator / test fallback — immediately reports overhead
final class MockARMeasurementService: ARMeasurementService {
    func currentGuidance() async -> CameraHeightGuidance {
        CameraHeightGuidance.captureReadyMock
    }
}

// Real tilt detection via CoreMotion. Height estimation is composition-based (no ARKit needed).
final class CMMotionMeasurementService: ARMeasurementService, @unchecked Sendable {
    private let motionManager = CMMotionManager()

    init() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    func currentGuidance() async -> CameraHeightGuidance {
        guard let motion = motionManager.deviceMotion else { return awaiting() }

        let g = motion.gravity
        // acos(-z) = 0 when pointing straight down, 90 when horizontal
        let tiltDeg = acos(max(-1.0, min(1.0, -g.z))) * 180.0 / .pi
        let isTopDown = tiltDeg < 25.0

        let label: String
        switch tiltDeg {
        case ..<25:  label = "Top-down locked"
        case ..<45:  label = "Tilt a little more"
        default:     label = "Point straight down"
        }

        return CameraHeightGuidance(
            currentCentimeters: 30,
            targetRange: 27...33,
            targetCentimeters: 30,
            directionLabel: label,
            isReady: isTopDown,
            tiltDegrees: tiltDeg,
            isTopDown: isTopDown
        )
    }

    private func awaiting() -> CameraHeightGuidance {
        CameraHeightGuidance(
            currentCentimeters: 30,
            targetRange: 27...33,
            targetCentimeters: 30,
            directionLabel: "Checking angle…",
            isReady: false,
            tiltDegrees: 45,
            isTopDown: false
        )
    }
}
