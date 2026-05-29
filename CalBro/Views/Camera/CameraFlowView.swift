import SwiftUI
import UIKit

// MARK: - Entry point

struct CameraFlowView: View {
    @State private var viewModel = CameraFlowViewModel()
    @State private var camera   = CameraCaptureController()
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
                .opacity(previewOpacity)
                .animation(.easeInOut(duration: 0.3), value: previewOpacity)

            // Aiming progress arc — visible only during .aiming phase
            if case .aiming = viewModel.phase {
                AimingProgressArc(progress: viewModel.aimingProgress)
                    .transition(.opacity)
            }

            // Composition ring — locked when overhead
            if viewModel.phase != .scanning {
                CompositionRing(phase: viewModel.phase)
                    .transition(.scale.combined(with: .opacity))
            }

            // Countdown number
            if case .countdown(let n) = viewModel.phase {
                CountdownOverlay(n: n)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            }

            if viewModel.phase == .processing {
                ProcessingOverlay()
            }

            cameraChrome

            if viewModel.phase == .result, let r = viewModel.result {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .transition(.opacity)
                ResultSheet(result: r, viewModel: viewModel, onClose: onClose)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: viewModel.phase)
        .task {
            camera.start()
            await viewModel.run(camera: camera)
        }
        .onDisappear { camera.stop() }
    }

    // MARK: Opacity

    private var previewOpacity: Double {
        switch viewModel.phase {
        case .scanning:   return 0.72
        case .processing: return 0.5
        case .result:     return 0.35
        default:          return 1.0
        }
    }

    // MARK: Chrome

    private var cameraChrome: some View {
        VStack(spacing: 0) {
            // Top bar: close + angle bubble
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                AngleBubble(tiltDegrees: viewModel.tiltDegrees)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Height guidance — universal distance bar (no units), shown during scan/aim
            if viewModel.phase == .scanning || viewModel.phase == .aiming {
                HeightGuidanceBar(heightCm: viewModel.heightCm,
                                  range: CameraFlowViewModel.heightRange)
                    .padding(.top, 12)
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            if viewModel.phase != .result {
                bottomHUD
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Bottom HUD — dark solid, NO glass over camera

    private var bottomHUD: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(guidanceTitle)
                    .font(CBTypography.body(17, weight: .bold))
                    .foregroundStyle(guidanceTitleColor)

                // Aiming progress bar
                if case .aiming = viewModel.phase {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18)).frame(height: 4)
                            Capsule().fill(CBColors.sage)
                                .frame(width: geo.size.width * viewModel.aimingProgress, height: 4)
                                .animation(.linear(duration: 0.05), value: viewModel.aimingProgress)
                        }
                    }
                    .frame(height: 4)
                } else {
                    Text(guidanceSubtitle)
                        .font(CBTypography.body(13))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer(minLength: 8)

            // Manual shutter — available during scanning or aiming
            if viewModel.phase == .scanning || viewModel.phase == .aiming {
                Button { viewModel.manualCapture(camera: camera) } label: {
                    ZStack {
                        Circle().stroke(.white.opacity(0.85), lineWidth: 3).frame(width: 58, height: 58)
                        Circle().fill(.white).frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        // Dark solid background — no glass on camera
        .background(
            RoundedRectangle(cornerRadius: CBSpacing.glassRadius, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: CBSpacing.glassRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var guidanceTitle: String {
        switch viewModel.phase {
        case .scanning:
            if viewModel.tiltDegrees >= 28 { return "Point straight down" }
            if let h = viewModel.heightCm {
                if h < CameraFlowViewModel.heightRange.lowerBound { return "Raise the phone a little" }
                if h > CameraFlowViewModel.heightRange.upperBound { return "Lower the phone a little" }
            }
            return "Point straight down"
        case .aiming:             return "Hold steady…"
        case .countdown(let n):   return "\(n)"
        case .processing:         return "Analysing…"
        case .result:             return ""
        }
    }

    private var guidanceTitleColor: Color {
        switch viewModel.phase {
        case .aiming, .countdown: return CBColors.sage
        case .scanning:
            if let h = viewModel.heightCm, !CameraFlowViewModel.heightRange.contains(h) {
                return CBColors.gold
            }
            return .white
        default: return .white
        }
    }

    private var guidanceSubtitle: String {
        switch viewModel.phase {
        case .scanning:
            let anglePart = "\(Int(viewModel.tiltDegrees))° from overhead"
            return "\(anglePart) · auto-captures when aligned"
        case .aiming:
            return "Locking…"
        case .countdown:
            return "Keep still"
        case .processing:
            return "Running DPF + Depth Anything V2"
        case .result:
            return ""
        }
    }
}

// MARK: - Height guidance bar (universal, no units)

/// Shows distance to the food as a position on a track with a centered "sweet zone".
/// No numbers/units — works for anyone regardless of metric/imperial familiarity.
private struct HeightGuidanceBar: View {
    let heightCm: Double?
    let range: ClosedRange<Double>

    /// Visible window a bit wider than the sweet zone so the marker has room to travel.
    private let window: ClosedRange<Double> = 18...43

    private var inRange: Bool {
        guard let h = heightCm else { return false }
        return range.contains(h)
    }
    private var tooClose: Bool {
        guard let h = heightCm else { return false }
        return h < range.lowerBound
    }
    private var tooFar: Bool {
        guard let h = heightCm else { return false }
        return h > range.upperBound
    }

    private func frac(_ value: Double) -> Double {
        let clamped = min(max(value, window.lowerBound), window.upperBound)
        return (clamped - window.lowerBound) / (window.upperBound - window.lowerBound)
    }

    private var accent: Color { inRange ? CBColors.sage : CBColors.gold }

    private var label: String {
        guard heightCm != nil else { return "Measuring distance…" }
        if inRange { return "Perfect — hold steady" }
        if tooClose { return "Move up ↑" }
        return "Move down ↓"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if inRange {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .bold))
                } else if heightCm != nil {
                    Image(systemName: tooClose ? "arrow.up" : "arrow.down").font(.system(size: 12, weight: .bold))
                }
                Text(label).font(CBTypography.body(13, weight: .semibold))
            }
            .foregroundStyle(heightCm == nil ? .white.opacity(0.7) : accent)

            GeometryReader { geo in
                let w = geo.size.width
                let zoneLo = frac(range.lowerBound)
                let zoneHi = frac(range.upperBound)
                ZStack(alignment: .leading) {
                    // Track
                    Capsule().fill(Color.white.opacity(0.16)).frame(height: 6)
                    // Sweet zone band
                    Capsule().fill(CBColors.sage.opacity(0.45))
                        .frame(width: max(0, (zoneHi - zoneLo) * w), height: 6)
                        .offset(x: zoneLo * w)
                    // Current-distance marker
                    if let h = heightCm {
                        Circle()
                            .fill(accent)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                            .offset(x: frac(h) * w - 8)
                            .animation(.spring(duration: 0.25), value: h)
                    }
                }
                .frame(height: 16)
            }
            .frame(height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(inRange ? CBColors.sage.opacity(0.5) : Color.white.opacity(0.16), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: inRange)
    }
}

// MARK: - Aiming progress arc (green ring fills over 2.5 s)

private struct AimingProgressArc: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 4)
                .padding(32)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(CBColors.sage, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(32)
                .animation(.linear(duration: 0.05), value: progress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Angle bubble (top-right)

private struct AngleBubble: View {
    let tiltDegrees: Double
    private var isGood: Bool { tiltDegrees < 28 }

    private var dotOffset: CGSize {
        let t = min(tiltDegrees / 70, 1.0)
        return CGSize(width: 0, height: CGFloat(t) * 12)
    }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.28), lineWidth: 1.5).frame(width: 42, height: 42)
            Circle().stroke(isGood ? CBColors.sage.opacity(0.5) : .clear, lineWidth: 2).frame(width: 42, height: 42)
            Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 14)
            Rectangle().fill(.white.opacity(0.18)).frame(width: 14, height: 1)
            Circle()
                .fill(isGood ? CBColors.sage : CBColors.gold)
                .frame(width: 10, height: 10)
                .offset(dotOffset)
                .animation(.interactiveSpring(duration: 0.15), value: dotOffset)
        }
        .frame(width: 42, height: 42)
    }
}

// MARK: - Composition ring

private struct CompositionRing: View {
    let phase: CapturePhase

    private var isLocked: Bool {
        switch phase {
        case .aiming, .countdown, .processing: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: isLocked ? [] : [6, 4]))
                .foregroundStyle(isLocked ? CBColors.sage.opacity(0.7) : .white.opacity(0.35))
                .padding(40)
                .animation(.easeInOut(duration: 0.4), value: isLocked)
            if isLocked {
                ForEach(0..<4, id: \.self) { idx in
                    CornerBracket(index: idx, color: CBColors.sage)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CornerBracket: View {
    let index: Int
    let color: Color
    let size: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, m: CGFloat = 40
            let x = index % 2 == 0 ? m : w - m - size
            let y = index < 2     ? m : h - m - size
            let xFlip = index % 2 == 1, yFlip = index >= 2
            Path { path in
                let ox: CGFloat = xFlip ? size : 0, oy: CGFloat = yFlip ? size : 0
                path.move(to: CGPoint(x: ox + (xFlip ? -size : size), y: oy))
                path.addLine(to: CGPoint(x: ox, y: oy))
                path.addLine(to: CGPoint(x: ox, y: oy + (yFlip ? -size : size)))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .position(x: x + size / 2, y: y + size / 2)
        }
    }
}

// MARK: - Countdown

private struct CountdownOverlay: View {
    let n: Int
    var body: some View {
        Text("\(n)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(CBColors.sage)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .id(n)
    }
}

// MARK: - Processing

private struct ProcessingOverlay: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
            .padding(24)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Result sheet

private struct ResultSheet: View {
    let result: FoodRecognitionResult
    @Bindable var viewModel: CameraFlowViewModel
    let onClose: () -> Void
    @State private var multiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 14).padding(.bottom, 18)

            // Photo + name
            if let data = viewModel.capturedImageData, let img = UIImage(data: data) {
                HStack(spacing: 14) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.foodName)
                            .font(CBTypography.title(20)).foregroundStyle(.white)
                        Text(result.servingDescription)
                            .font(CBTypography.body(13)).foregroundStyle(.white.opacity(0.55))
                        HStack(spacing: 6) {
                            PillTag(text: "\(Int(result.confidence * 100))% match", color: CBColors.sage, filled: true)
                            PillTag(
                                text: result.modelFamily,
                                color: result.modelFamily.hasPrefix("Fallback") ? CBColors.gold : CBColors.sage,
                                filled: false
                            )
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Int((Double(result.calories) * multiplier).rounded()))")
                            .font(CBTypography.display(30)).foregroundStyle(CBColors.terra)
                        Text("kcal").font(CBTypography.body(12)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 16)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.foodName)
                            .font(CBTypography.title(20)).foregroundStyle(.white)
                        Text(result.servingDescription)
                            .font(CBTypography.body(13)).foregroundStyle(.white.opacity(0.55))
                        PillTag(
                            text: result.modelFamily,
                            color: result.modelFamily.hasPrefix("Fallback") ? CBColors.gold : CBColors.sage,
                            filled: false
                        )
                    }
                    Spacer()
                    Text("\(Int((Double(result.calories) * multiplier).rounded())) kcal")
                        .font(CBTypography.body(22, weight: .bold)).foregroundStyle(CBColors.terra)
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 16)
            }

            // Macro pills
            HStack(spacing: 8) {
                MacroPill(label: "Protein", value: "\(Int((Double(result.protein) * multiplier).rounded()))g", color: CBColors.plum)
                MacroPill(label: "Carbs",   value: "\(Int((Double(result.carbs)   * multiplier).rounded()))g", color: CBColors.ocean)
                MacroPill(label: "Fat",     value: "\(Int((Double(result.fat)     * multiplier).rounded()))g", color: CBColors.gold)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CBSpacing.page).padding(.bottom, 16)

            // Serving stepper
            HStack {
                Text("Serving").font(CBTypography.body(14)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                HStack(spacing: 20) {
                    Button { if multiplier > 0.5 { multiplier -= 0.5 } } label: {
                        Image(systemName: "minus").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }.buttonStyle(.plain)
                    Text("\(multiplier, specifier: "%.1f")×")
                        .font(CBTypography.body(17, weight: .bold)).foregroundStyle(.white).frame(minWidth: 44)
                    Button { if multiplier < 4 { multiplier += 0.5 } } label: {
                        Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CBSpacing.page).padding(.bottom, 18)

            // Add button
            Button {
                viewModel.addToLog(multiplier: multiplier)
                onClose()
            } label: {
                Text("Add to Today")
                    .font(CBTypography.body(17, weight: .semibold))
                    .foregroundStyle(CBColors.controlOnFill)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(CBColors.controlFill)
                    .clipShape(RoundedRectangle(cornerRadius: CBSpacing.buttonRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CBSpacing.page)

            Button("Retake") { viewModel.dismissResult() }
                .font(CBTypography.body(14)).foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity).padding(.top, 12).buttonStyle(.plain)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct MacroPill: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(CBTypography.body(15, weight: .bold)).foregroundStyle(color)
            Text(label).font(CBTypography.body(10)).foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(color.opacity(0.12)).overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
        .clipShape(Capsule())
    }
}
