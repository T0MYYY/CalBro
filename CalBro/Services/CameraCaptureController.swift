import Foundation
@preconcurrency import AVFoundation
import UIKit
import os.log

private let camLog = OSLog(subsystem: "com.wydfcc.calbro", category: "Camera")

enum CameraCaptureStatus: Equatable {
    case idle
    case requestingPermission
    case starting
    case running
    case unavailable(String)

    var message: String {
        switch self {
        case .idle:                  "Camera idle"
        case .requestingPermission:  "Requesting camera access"
        case .starting:              "Starting camera"
        case .running:               "Camera ready"
        case .unavailable(let r):    r
        }
    }

    var canCapture: Bool {
        if case .running = self { return true }
        return false
    }
}

enum CameraCaptureError: LocalizedError {
    case unavailable
    case captureInProgress
    case noPhotoData

    var errorDescription: String? {
        switch self {
        case .unavailable:      "Camera is unavailable"
        case .captureInProgress:"A capture is already in progress"
        case .noPhotoData:      "No photo data was captured"
        }
    }
}

@MainActor
@Observable
final class CameraCaptureController: NSObject, @unchecked Sendable {
    var status: CameraCaptureStatus = .idle
    /// Actual measured height above surface in cm, nil when depth unavailable
    private(set) var currentHeightCm: Double? = nil
    /// Latest LiDAR/disparity depth frame (Float32, meters), nil when unavailable
    private(set) var currentDepthBuffer: CVPixelBuffer? = nil

    private let box = CameraSessionBox()

    var session: AVCaptureSession { box.session }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingPermission
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted { configureAndStart() }
                else { status = .unavailable("Camera permission denied") }
            }
        case .denied, .restricted:
            status = .unavailable("Enable Camera access in Settings")
        @unknown default:
            status = .unavailable("Camera authorization unavailable")
        }
    }

    func stop() { box.stop() }

    func capturePhotoData() async throws -> Data {
        guard status.canCapture else { throw CameraCaptureError.unavailable }
        return try await box.capturePhotoData()
    }

    private func configureAndStart() {
        status = .starting
        box.configureAndStart { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success:
                    self?.status = .running
                    self?.box.onDepthSample = { [weak self] cm, depthBuf in
                        self?.currentHeightCm = cm
                        self?.currentDepthBuffer = depthBuf
                    }
                case .failure(let error):
                    self?.status = .unavailable(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - CameraSessionBox

private final class CameraSessionBox: NSObject,
    AVCapturePhotoCaptureDelegate,
    AVCaptureDepthDataOutputDelegate,
    @unchecked Sendable
{
    let session = AVCaptureSession()
    /// Callback: (heightCm, depthBuffer?) — called on main thread each depth frame
    var onDepthSample: ((Double?, CVPixelBuffer?) -> Void)?

    private let sessionQueue   = DispatchQueue(label: "calbro.camera.session", qos: .userInitiated)
    private let photoOutput    = AVCapturePhotoOutput()
    private let depthOutput    = AVCaptureDepthDataOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    private var configured = false

    // Rolling average (last 8 frames) for stable height reading
    private var depthSamples: [Double] = []
    private let depthSampleCapacity = 8
    private var depthFrameCount = 0

    func configureAndStart(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.configured {
                    try self.configureSession()
                    self.configured = true
                }
                if !self.session.isRunning { self.session.startRunning() }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhotoData() async throws -> Data {
        guard photoContinuation == nil else { throw CameraCaptureError.captureInProgress }
        return try await withCheckedThrowingContinuation { cont in
            photoContinuation = cont
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            sessionQueue.async { [photoOutput, weak self] in
                guard self != nil else { cont.resume(throwing: CameraCaptureError.unavailable); return }
                photoOutput.capturePhoto(with: settings, delegate: self!)
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        // *** Critical: the plain wide-angle camera does NOT provide depth on the back.
        // LiDAR/dual-cam depth comes from virtual devices. Prefer those, in priority order. ***
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInLiDARDepthCamera,   // iPhone Pro — true LiDAR depth (meters)
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera,
            .builtInWideAngleCamera     // last resort — no depth, photo only
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes, mediaType: .video, position: .back
        )
        os_log("[CB-CAM] discovered back devices: %{public}@", log: camLog,
               discovery.devices.map { "\($0.deviceType.rawValue)(depthFmts=\($0.activeFormat.supportedDepthDataFormats.count))" }.joined(separator: ", "))

        // Pick first device that actually exposes depth formats; else any available.
        let device = discovery.devices.first(where: { !$0.activeFormat.supportedDepthDataFormats.isEmpty })
            ?? discovery.devices.first
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            throw CameraCaptureError.unavailable
        }
        os_log("[CB-CAM] selected device: %{public}@", log: camLog, device.deviceType.rawValue)
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraCaptureError.unavailable }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        // Add depth output and enable its connection.
        var depthEnabled = false
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = true
            depthOutput.alwaysDiscardsLateDepthData = true
            depthOutput.setDelegate(self, callbackQueue: sessionQueue)
            if let conn = depthOutput.connection(with: .depthData) {
                conn.isEnabled = true
            }
            depthEnabled = true
        }
        os_log("[CB-CAM] depth output added: %{public}@", log: camLog, depthEnabled ? "YES" : "NO")

        // *** Must set activeDepthDataFormat (after outputs added) or delegate never fires ***
        // Prefer Float32 (LiDAR native, meters); fall back to any available depth format.
        let depthFormats = device.activeFormat.supportedDepthDataFormats
        let preferredFormat = depthFormats
            .filter { CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32 }
            .first ?? depthFormats.first
        os_log("[CB-CAM] depth formats on activeFormat: %{public}d, preferred=%{public}@", log: camLog,
               depthFormats.count, preferredFormat != nil ? "set" : "NONE")
        if let df = preferredFormat {
            do {
                try device.lockForConfiguration()
                device.activeDepthDataFormat = df
                device.unlockForConfiguration()
                os_log("[CB-CAM] activeDepthDataFormat set ✓", log: camLog)
            } catch {
                os_log("[CB-CAM] lockForConfiguration failed: %{public}@", log: camLog, type: .error, "\(error)")
            }
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let cont = photoContinuation
        photoContinuation = nil
        if let error { cont?.resume(throwing: error); return }
        guard let data = photo.fileDataRepresentation() else {
            cont?.resume(throwing: CameraCaptureError.noPhotoData); return
        }
        cont?.resume(returning: data)
    }

    // MARK: - AVCaptureDepthDataOutputDelegate

    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        // Convert to absolute depth in meters (disparity → depth if needed)
        let targetType: OSType = kCVPixelFormatType_DepthFloat32
        let converted: AVDepthData
        if depthData.depthDataType != targetType {
            converted = depthData.converting(toDepthDataType: targetType)
        } else {
            converted = depthData
        }

        let buf = converted.depthDataMap
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }

        let w = CVPixelBufferGetWidth(buf)
        let h = CVPixelBufferGetHeight(buf)
        let bpr = CVPixelBufferGetBytesPerRow(buf)
        guard let base = CVPixelBufferGetBaseAddress(buf) else { return }

        // Sample center 20% region for height scalar
        let cx = w / 2, cy = h / 2
        let rx = max(1, w / 10), ry = max(1, h / 10)
        var sum: Double = 0, count: Double = 0
        for py in stride(from: max(0, cy - ry), through: min(h - 1, cy + ry), by: 1) {
            let row = base.advanced(by: py * bpr).assumingMemoryBound(to: Float32.self)
            for px in stride(from: max(0, cx - rx), through: min(w - 1, cx + rx), by: 1) {
                let v = Double(row[px])
                if v > 0.05 && v < 3.0 { sum += v; count += 1 }
            }
        }

        // Rolling average
        let cm: Double?
        if count > 0 {
            depthSamples.append(sum / count)
            if depthSamples.count > depthSampleCapacity { depthSamples.removeFirst() }
            cm = (depthSamples.reduce(0, +) / Double(depthSamples.count)) * 100.0
        } else {
            cm = nil
        }

        // Keep a reference to the depth buffer for use as DPF input (bypasses DA2)
        let retainedBuf = converted.depthDataMap

        depthFrameCount += 1
        if depthFrameCount == 1 || depthFrameCount % 30 == 0 {
            os_log("[CB-CAM] depth frame #%{public}d  %{public}dx%{public}d  validPx=%{public}d  height=%{public}@cm",
                   log: camLog, depthFrameCount, w, h, Int(count),
                   cm != nil ? String(format: "%.1f", cm!) : "nil")
        }

        DispatchQueue.main.async { [weak self] in
            self?.onDepthSample?(cm, retainedBuf)
        }
    }
}
