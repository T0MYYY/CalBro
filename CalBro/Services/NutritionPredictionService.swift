import Foundation
import CoreML
import UIKit
import os.log

private let mlLog = OSLog(subsystem: "com.wydfcc.calbro", category: "CoreML")

protocol NutritionPredictionService: Sendable {
    func predictNutrition(from imageData: Data, guidance: CameraHeightGuidance) async throws -> NutritionPrediction
}

// MARK: - Mock

final class MockNutritionPredictionService: NutritionPredictionService {
    func predictNutrition(from imageData: Data, guidance: CameraHeightGuidance) async throws -> NutritionPrediction {
        try await Task.sleep(for: .milliseconds(600))
        return NutritionPrediction(
            foodName: "Mixed bowl", servingDescription: "1 serving · ~320g",
            confidence: 0.91, calories: 520, protein: 32, carbs: 68, fat: 14,
            modelFamily: "Mock"
        )
    }
}

// MARK: - CoreML (Depth Anything V2 → DPF Food2K)

final class CoreMLNutritionPredictionService: NutritionPredictionService, @unchecked Sendable {

    private struct LoadedModels: @unchecked Sendable {
        let depth: MLModel      // DA2: image → depth (GRAYSCALE_FLOAT16)
        let nutrition: MLModel  // DPF: rgb+depth → nutrition[1,5]
    }

    private let loadingTask: Task<LoadedModels?, Never>

    init() {
        loadingTask = Task.detached(priority: .userInitiated) {
            await CoreMLNutritionPredictionService.loadModels()
        }
    }

    func predictNutrition(from imageData: Data, guidance: CameraHeightGuidance) async throws -> NutritionPrediction {
        guard let image = UIImage(data: imageData) else {
            return fallback("bad image data (size=\(imageData.count))")
        }
        os_log("[CB-ML] Awaiting models...", log: mlLog)
        guard let models = await loadingTask.value else {
            return fallback("models unavailable — check Xcode console for path errors")
        }
        os_log("[CB-ML] Models ready, running pipeline", log: mlLog)
        do {
            return try await runPipeline(image: image, models: models)
        } catch {
            os_log("[CB-ML] Pipeline error: %{public}@", log: mlLog, "\(error)")
            return fallback("pipeline: \(error)")
        }
    }

    // MARK: - Pipeline

    private func runPipeline(image: UIImage, models: LoadedModels) async throws -> NutritionPrediction {
        let da2Size = Self.da2InputSize  // fixed 518×392 per model spec
        os_log("[CB-ML] DA2 input: 518×392 (fixed per protobuf spec)", log: mlLog)

        guard let da2Image = image.resized(to: da2Size),
              let pixelBuf = da2Image.toCVPixelBuffer() else {
            throw InferenceError.preprocessingFailed
        }

        // Log DA2 model description
        let da2Inputs  = models.depth.modelDescription.inputDescriptionsByName.keys.sorted()
        let da2Outputs = models.depth.modelDescription.outputDescriptionsByName.keys.sorted()
        os_log("[CB-ML] DA2 inputs: %{public}@  outputs: %{public}@", log: mlLog,
               da2Inputs.joined(separator: ","), da2Outputs.joined(separator: ","))

        let da2Input = try MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: pixelBuf)
        ])
        let da2Out: MLFeatureProvider
        do {
            da2Out = try await models.depth.prediction(from: da2Input)
        } catch {
            os_log("[CB-ML] DA2 prediction failed: %{public}@", log: mlLog, "\(error)")
            throw InferenceError.modelPredictionFailed("DA2: \(error)")
        }

        // Log all output feature names so we can verify the key
        let allDepthKeys = da2Out.featureNames
        os_log("[CB-ML] DA2 output keys: %{public}@", log: mlLog, allDepthKeys.sorted().joined(separator: ","))

        guard let depthFV = da2Out.featureValue(for: "depth") else {
            os_log("[CB-ML] 'depth' key missing — available: %{public}@", log: mlLog,
                   allDepthKeys.sorted().joined(separator: ","))
            throw InferenceError.outputMissing("depth key not found in DA2 output")
        }

        os_log("[CB-ML] DA2 depth feature type: %{public}@", log: mlLog, "\(depthFV.type.rawValue)")

        guard let depthBuf = depthFV.imageBufferValue else {
            // Try multiArrayValue as fallback (some CoreML versions wrap differently)
            os_log("[CB-ML] depth imageBufferValue is nil — feature type=%{public}@", log: mlLog,
                   "\(depthFV.type.rawValue)")
            throw InferenceError.outputMissing("depth imageBufferValue nil (type=\(depthFV.type.rawValue))")
        }

        let depthW = CVPixelBufferGetWidth(depthBuf)
        let depthH = CVPixelBufferGetHeight(depthBuf)
        let depthFmt = CVPixelBufferGetPixelFormatType(depthBuf)
        os_log("[CB-ML] DA2 depth buffer: %{public}@x%{public}@ fmt=0x%{public}@", log: mlLog,
               "\(depthW)", "\(depthH)", String(format: "%08X", depthFmt))

        // Prepare DPF inputs
        let rgbArray   = try image.toMLMultiArray(height: 336, width: 448)
        let depthArray = try depthBufferToMLArray(depthBuf, height: 336, width: 448)

        // Log DPF model description
        let dpfInputs  = models.nutrition.modelDescription.inputDescriptionsByName.keys.sorted()
        let dpfOutputs = models.nutrition.modelDescription.outputDescriptionsByName.keys.sorted()
        os_log("[CB-ML] DPF inputs: %{public}@  outputs: %{public}@", log: mlLog,
               dpfInputs.joined(separator: ","), dpfOutputs.joined(separator: ","))

        let dpfInput = try MLDictionaryFeatureProvider(dictionary: [
            "rgb":   MLFeatureValue(multiArray: rgbArray),
            "depth": MLFeatureValue(multiArray: depthArray)
        ])
        let dpfOut: MLFeatureProvider
        do {
            dpfOut = try await models.nutrition.prediction(from: dpfInput)
        } catch {
            os_log("[CB-ML] DPF prediction failed: %{public}@", log: mlLog, "\(error)")
            throw InferenceError.modelPredictionFailed("DPF: \(error)")
        }

        let allNutKeys = dpfOut.featureNames
        os_log("[CB-ML] DPF output keys: %{public}@", log: mlLog, allNutKeys.sorted().joined(separator: ","))

        guard let nutrition = dpfOut.featureValue(for: "nutrition")?.multiArrayValue else {
            os_log("[CB-ML] 'nutrition' key missing — available: %{public}@", log: mlLog,
                   allNutKeys.sorted().joined(separator: ","))
            throw InferenceError.outputMissing("nutrition")
        }

        // [calories, mass, fat, carb, protein] — float16 MLMultiArray
        let cal   = max(0, nutrition[0].intValue)
        let massG = max(0, nutrition[1].intValue)
        let fat   = max(0, nutrition[2].intValue)
        let carb  = max(0, nutrition[3].intValue)
        let prot  = max(0, nutrition[4].intValue)

        os_log("[CB-ML] DPF raw output: cal=%{public}d mass=%{public}d fat=%{public}d carb=%{public}d prot=%{public}d",
               log: mlLog, cal, massG, fat, carb, prot)

        return NutritionPrediction(
            foodName: "Scanned meal",
            servingDescription: massG > 0 ? "\(massG) g estimated" : "Estimated portion",
            confidence: 0.85,
            calories: cal, protein: prot, carbs: carb, fat: fat,
            modelFamily: "DPF+DA2 ✓"
        )
    }

    // MARK: - Model Loading

    private static func loadModels() async -> LoadedModels? {
        guard let resourceURL = Bundle.main.resourceURL else {
            os_log("[CB-ML] Bundle.main.resourceURL is nil!", log: mlLog, type: .error)
            return nil
        }
        let modelsDir = resourceURL.appendingPathComponent("Models")
        os_log("[CB-ML] Models dir: %{public}@", log: mlLog, modelsDir.path)
        os_log("[CB-ML] Models dir exists: %{public}@", log: mlLog,
               FileManager.default.fileExists(atPath: modelsDir.path) ? "YES" : "NO")

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CB_Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let da2Source = modelsDir
            .appendingPathComponent("depth-anything-v2-small")
            .appendingPathComponent("DepthAnythingV2SmallF16P6.mlpackage")
        let dpfSource = modelsDir.appendingPathComponent("DPFNutritionRGBDepth.mlpackage")

        os_log("[CB-ML] DA2 path: %{public}@  exists=%{public}@", log: mlLog,
               da2Source.path, FileManager.default.fileExists(atPath: da2Source.path) ? "YES" : "NO")
        os_log("[CB-ML] DPF path: %{public}@  exists=%{public}@", log: mlLog,
               dpfSource.path, FileManager.default.fileExists(atPath: dpfSource.path) ? "YES" : "NO")

        async let da2 = compileOrLoad(
            name: "DA2",
            source: da2Source,
            cache: cacheDir.appendingPathComponent("DA2.mlmodelc")
        )
        async let dpf = compileOrLoad(
            name: "DPF",
            source: dpfSource,
            cache: cacheDir.appendingPathComponent("DPF.mlmodelc")
        )

        guard let d = await da2 else {
            os_log("[CB-ML] DA2 model failed to load — pipeline unavailable", log: mlLog, type: .error)
            return nil
        }
        guard let n = await dpf else {
            os_log("[CB-ML] DPF model failed to load — pipeline unavailable", log: mlLog, type: .error)
            return nil
        }
        os_log("[CB-ML] Both models loaded successfully", log: mlLog)
        return LoadedModels(depth: d, nutrition: n)
    }

    private static func compileOrLoad(name: String, source: URL, cache: URL) async -> MLModel? {
        // 1. Try cache (fast path after first install)
        if FileManager.default.fileExists(atPath: cache.path) {
            do {
                let m = try MLModel(contentsOf: cache)
                os_log("[CB-ML] %{public}@ loaded from cache", log: mlLog, name)
                return m
            } catch {
                os_log("[CB-ML] %{public}@ cache corrupt (%{public}@), recompiling...", log: mlLog, name, "\(error)")
                try? FileManager.default.removeItem(at: cache)
            }
        }

        // 2. Verify source exists
        guard FileManager.default.fileExists(atPath: source.path) else {
            os_log("[CB-ML] %{public}@ source not found at: %{public}@", log: mlLog, type: .error, name, source.path)
            return nil
        }

        // 3. Direct load of .mlpackage (iOS 16+ — no explicit compilation needed)
        os_log("[CB-ML] %{public}@ direct loading .mlpackage...", log: mlLog, name)
        do {
            let m = try MLModel(contentsOf: source)
            os_log("[CB-ML] %{public}@ direct load succeeded", log: mlLog, name)
            return m
        } catch {
            os_log("[CB-ML] %{public}@ direct load failed: %{public}@", log: mlLog, name, "\(error)")
        }

        // 4. Explicit compile (writes .mlmodelc to tmp, then copy to cache)
        os_log("[CB-ML] %{public}@ trying MLModel.compileModel...", log: mlLog, name)
        do {
            let compiledURL = try await MLModel.compileModel(at: source)
            os_log("[CB-ML] %{public}@ compiled → %{public}@", log: mlLog, name, compiledURL.path)
            do {
                try FileManager.default.copyItem(at: compiledURL, to: cache)
                let m = try MLModel(contentsOf: cache)
                os_log("[CB-ML] %{public}@ loaded from compiled cache", log: mlLog, name)
                return m
            } catch {
                os_log("[CB-ML] %{public}@ cache copy failed, loading from temp: %{public}@", log: mlLog, name, "\(error)")
                let m = try MLModel(contentsOf: compiledURL)
                return m
            }
        } catch {
            os_log("[CB-ML] %{public}@ compileModel failed: %{public}@", log: mlLog, type: .error, name, "\(error)")
        }

        os_log("[CB-ML] %{public}@ ALL load attempts failed", log: mlLog, type: .error, name)
        return nil
    }

    // MARK: - Helpers



    // DA2 model protobuf spec declares exactly: width=518, height=392 (both multiples of 14).
    // The model description text is misleading; the actual enumerated size is fixed at 518×392.
    private static let da2InputSize = CGSize(width: 518, height: 392)

    private func fallback(_ reason: String) -> NutritionPrediction {
        os_log("[CB-ML] Using fallback — reason: %{public}@", log: mlLog, type: .error, reason)
        return NutritionPrediction(
            foodName: "Meal detected", servingDescription: "Estimation only",
            confidence: 0.50, calories: 450, protein: 28, carbs: 60, fat: 12,
            modelFamily: "Fallback: \(reason)"
        )
    }
}

enum InferenceError: Error {
    case preprocessingFailed
    case outputMissing(String)
    case modelPredictionFailed(String)
}
