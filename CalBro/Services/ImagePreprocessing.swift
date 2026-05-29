import UIKit
import CoreML
import Accelerate

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // Returns 32BGRA CVPixelBuffer — CoreML accepts this for image inputs
    func toCVPixelBuffer(format: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
        let w = Int(size.width), h = Int(size.height)
        var buf: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(nil, w, h, format, attrs as CFDictionary, &buf) == kCVReturnSuccess,
              let pb = buf else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cg = cgImage else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return pb
    }

    // Returns MLMultiArray [1, 3, H, W] float32 with ImageNet normalisation
    func toMLMultiArray(height: Int, width: Int) throws -> MLMultiArray {
        guard let resizedImg = resized(to: CGSize(width: width, height: height)),
              let cg = resizedImg.cgImage else { throw CocoaError(.fileReadUnknown) }

        let array = try MLMultiArray(
            shape: [1, 3, NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        )
        var rgba = [UInt8](repeating: 0, count: height * width * 4)
        guard let ctx = CGContext(
            data: &rgba, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw CocoaError(.fileReadUnknown) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let mean: [Float] = [0.485, 0.456, 0.406]
        let std:  [Float] = [0.229, 0.224, 0.225]
        let n = height * width
        let ptr = array.dataPointer.bindMemory(to: Float32.self, capacity: 3 * n)
        for i in 0..<n {
            let base = i * 4
            for c in 0..<3 {
                ptr[c * n + i] = (Float(rgba[base + c]) / 255.0 - mean[c]) / std[c]
            }
        }
        return array
    }
}

// Converts a CVPixelBuffer depth map (GRAYSCALE_FLOAT16 from DA2) to
// normalised MLMultiArray [1, 1, H, W] float32.
// Uses BGRA render target because CIContext reliably converts any grayscale
// format (including GRAYSCALE_FLOAT16) to BGRA on iOS.
func depthBufferToMLArray(_ buf: CVPixelBuffer, height: Int, width: Int) throws -> MLMultiArray {
    let ci = CIImage(cvPixelBuffer: buf)
    let srcW = CVPixelBufferGetWidth(buf)
    let srcH = CVPixelBufferGetHeight(buf)
    let scaled = ci.transformed(by: CGAffineTransform(
        scaleX: CGFloat(width)  / CGFloat(srcW),
        y:      CGFloat(height) / CGFloat(srcH)
    ))

    // Render to 32BGRA — reliable for GRAYSCALE_FLOAT16 source on all iOS versions
    var out: CVPixelBuffer?
    let attrs: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    guard CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA,
                              attrs as CFDictionary, &out) == kCVReturnSuccess,
          let outBuf = out else { throw CocoaError(.fileReadUnknown) }

    CIContext().render(scaled, to: outBuf)

    CVPixelBufferLockBaseAddress(outBuf, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(outBuf, .readOnly) }

    let array = try MLMultiArray(
        shape: [1, 1, NSNumber(value: height), NSNumber(value: width)],
        dataType: .float32
    )
    let ptr = array.dataPointer.bindMemory(to: Float32.self, capacity: height * width)
    let base = CVPixelBufferGetBaseAddress(outBuf)!
    let bpr  = CVPixelBufferGetBytesPerRow(outBuf)

    // Extract R channel (= G = B for grayscale) and find range for normalisation
    var minV: Float = 255, maxV: Float = 0
    for y in 0..<height {
        let row = base.advanced(by: y * bpr).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
            let v = Float(row[x * 4 + 2])   // R in BGRA layout
            if v < minV { minV = v }
            if v > maxV { maxV = v }
        }
    }
    let range = maxV > minV ? maxV - minV : 255.0
    for y in 0..<height {
        let row = base.advanced(by: y * bpr).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
            ptr[y * width + x] = (Float(row[x * 4 + 2]) - minV) / range
        }
    }
    return array
}
