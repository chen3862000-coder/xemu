import Foundation
import CoreGraphics

final class MarioFrameAnalyzer {
    private struct SpriteMetrics {
        let bounds: CGRect
        let pixelCount: Int
        let redRatio: Double
        let yellowRatio: Double
        let blueRatio: Double
        let meanLuma: Double
    }

    private let profile: MarioGameProfile
    private var previousSpriteMetrics: SpriteMetrics?
    private var previousFrameMeanLuma: Double?
    private var previousPlayerState: MarioPlayerState = .unknown
    private var previousPlayerBounds: CGRect?

    init(profile: MarioGameProfile) {
        self.profile = profile
    }

    func analyze(frameBufferInfo: FrameBufferInfo, timestamp: Date) -> MarioObservation {
        let surface = RGBASurface(frameBufferInfo: frameBufferInfo)
        let gameplayPhase = detectGameplayPhase(in: surface)
        let searchRegion = surface.denormalize(previousPlayerBounds.map { expanded(bounds: $0) } ?? profile.initialSearchRegion)
        let spriteMetrics = detectPlayer(in: surface, searchRegion: searchRegion) ??
            detectPlayer(in: surface, searchRegion: surface.denormalize(profile.initialSearchRegion))

        let playerState = classifyPlayerState(from: spriteMetrics)
        let playerStateConfidence = stateConfidence(for: playerState, metrics: spriteMetrics)
        let blinkConfidence = blinkConfidence(for: spriteMetrics)
        let hurtPoseConfidence = hurtPoseConfidence(for: spriteMetrics)
        let transitionFadeConfidence = fadeConfidence(for: surface)
        let lifeLossScreenConfidence = lifeLossConfidence(for: surface, gameplayPhase: gameplayPhase)
        let deathAnimationConfidence = deathConfidence(
            gameplayPhase: gameplayPhase,
            spriteMetrics: spriteMetrics,
            transitionFadeConfidence: transitionFadeConfidence,
            lifeLossScreenConfidence: lifeLossScreenConfidence
        )

        let observation = MarioObservation(
            playerState: playerState,
            playerStateConfidence: playerStateConfidence,
            blinkConfidence: blinkConfidence,
            hurtPoseConfidence: hurtPoseConfidence,
            deathAnimationConfidence: deathAnimationConfidence,
            transitionFadeConfidence: transitionFadeConfidence,
            lifeLossScreenConfidence: lifeLossScreenConfidence,
            gameplayPhase: gameplayPhase,
            playerBounds: spriteMetrics?.bounds.normalized(in: surface.size),
            memoryDebugSummary: nil,
            timestamp: timestamp
        )

        previousSpriteMetrics = spriteMetrics
        previousFrameMeanLuma = surface.meanLuma(in: surface.bounds)
        previousPlayerState = playerState
        previousPlayerBounds = observation.playerBounds
        return observation
    }

    private func detectGameplayPhase(in surface: RGBASurface) -> MarioGameplayPhase {
        let gameplayMeanLuma = surface.meanLuma(in: surface.denormalize(profile.gameplayRegion))
        let blackout = gameplayMeanLuma / 255.0
        if blackout < profile.blackoutThreshold {
            return .transition
        }

        let variance = surface.lumaVariance(in: surface.denormalize(profile.gameplayRegion))
        if variance < 45 {
            return .pausedMenu
        }
        return .gameplayActive
    }

    private func detectPlayer(in surface: RGBASurface, searchRegion: CGRect) -> SpriteMetrics? {
        let clampedRegion = searchRegion.intersection(surface.bounds)
        guard !clampedRegion.isNull, clampedRegion.width >= 4, clampedRegion.height >= 4 else { return nil }

        var minX = Int(clampedRegion.maxX)
        var minY = Int(clampedRegion.maxY)
        var maxX = Int(clampedRegion.minX)
        var maxY = Int(clampedRegion.minY)
        var pixelCount = 0
        var redCount = 0
        var yellowCount = 0
        var blueCount = 0
        var lumaSum = 0.0

        let startY = max(Int(clampedRegion.minY), 0)
        let endY = min(Int(clampedRegion.maxY), surface.height)
        let startX = max(Int(clampedRegion.minX), 0)
        let endX = min(Int(clampedRegion.maxX), surface.width)

        for y in stride(from: startY, to: endY, by: 2) {
            for x in stride(from: startX, to: endX, by: 2) {
                let pixel = surface.pixel(x: x, y: y)
                guard pixel.isMarioLike else { continue }
                pixelCount += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                lumaSum += pixel.luma
                if pixel.isRedDominant { redCount += 1 }
                if pixel.isYellowDominant { yellowCount += 1 }
                if pixel.isBlueDominant { blueCount += 1 }
            }
        }

        guard pixelCount >= 18, maxX > minX, maxY > minY else { return nil }
        let bounds = CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX + 1),
            height: CGFloat(maxY - minY + 1)
        )
        let invCount = 1.0 / Double(pixelCount)
        return SpriteMetrics(
            bounds: bounds,
            pixelCount: pixelCount,
            redRatio: Double(redCount) * invCount,
            yellowRatio: Double(yellowCount) * invCount,
            blueRatio: Double(blueCount) * invCount,
            meanLuma: lumaSum * invCount
        )
    }

    private func classifyPlayerState(from metrics: SpriteMetrics?) -> MarioPlayerState {
        guard let metrics else {
            return previousPlayerState == .dead ? .dead : .unknown
        }
        let height = metrics.bounds.height
        if profile.smallHeightRange.contains(height) {
            return .small
        }
        if profile.poweredUpHeightRange.contains(height), metrics.yellowRatio > 0.18 {
            return .poweredUp
        }
        if profile.superHeightRange.contains(height) {
            return .superState
        }
        if metrics.yellowRatio > 0.22 || metrics.redRatio > 0.32 {
            return .superState
        }
        return .unknown
    }

    private func stateConfidence(for state: MarioPlayerState, metrics: SpriteMetrics?) -> Double {
        guard let metrics else { return 0 }
        let areaScore = min(1.0, Double(metrics.pixelCount) / 140.0)
        switch state {
        case .small:
            return 0.52 + areaScore * 0.25
        case .superState:
            return 0.56 + areaScore * 0.24
        case .poweredUp:
            return 0.58 + min(0.22, metrics.yellowRatio)
        case .unknown, .hurt, .invulnerableBlink, .dead:
            return 0.18 + areaScore * 0.1
        }
    }

    private func blinkConfidence(for metrics: SpriteMetrics?) -> Double {
        guard let metrics, let previousSpriteMetrics else { return 0 }
        let lumaDelta = abs(metrics.meanLuma - previousSpriteMetrics.meanLuma) / 255.0
        let areaDelta = abs(metrics.bounds.height - previousSpriteMetrics.bounds.height) / max(previousSpriteMetrics.bounds.height, 1)
        // Reduced sensitivity to prevent false positives from normal gameplay variations
        return min(1.0, lumaDelta * 1.8 + Double(areaDelta) * 0.35)
    }

    private func hurtPoseConfidence(for metrics: SpriteMetrics?) -> Double {
        guard let metrics, let previousSpriteMetrics else { return 0 }
        let dx = abs(metrics.bounds.midX - previousSpriteMetrics.bounds.midX)
        let dy = abs(metrics.bounds.midY - previousSpriteMetrics.bounds.midY)
        let shift = Double(dx + dy) / 30.0
        let heightDelta = abs(metrics.bounds.height - previousSpriteMetrics.bounds.height) / max(previousSpriteMetrics.bounds.height, 1)
        // Reduced sensitivity to prevent false positives from normal player movement
        return min(1.0, shift * 0.45 + Double(heightDelta) * 0.32)
    }

    private func fadeConfidence(for surface: RGBASurface) -> Double {
        let current = surface.meanLuma(in: surface.bounds)
        defer { previousFrameMeanLuma = current }
        guard let previousFrameMeanLuma else { return 0 }
        let delta = max(0, previousFrameMeanLuma - current)
        return min(1.0, delta / 64.0)
    }

    private func lifeLossConfidence(for surface: RGBASurface, gameplayPhase: MarioGameplayPhase) -> Double {
        guard gameplayPhase != .gameplayActive else { return 0 }
        let meanLuma = surface.meanLuma(in: surface.bounds) / 255.0
        let variance = surface.lumaVariance(in: surface.bounds)
        if meanLuma < profile.blackoutThreshold {
            return 0.72
        }
        if variance < 28 {
            return 0.46
        }
        return 0.12
    }

    private func deathConfidence(
        gameplayPhase: MarioGameplayPhase,
        spriteMetrics: SpriteMetrics?,
        transitionFadeConfidence: Double,
        lifeLossScreenConfidence: Double
    ) -> Double {
        let trackerLost = spriteMetrics == nil && previousSpriteMetrics != nil ? 0.4 : 0
        let transitionBonus = gameplayPhase == .transition ? 0.22 : 0
        return min(1.0, transitionFadeConfidence * 0.48 + lifeLossScreenConfidence * 0.38 + trackerLost + transitionBonus)
    }

    private func expanded(bounds: CGRect) -> CGRect {
        CGRect(
            x: max(0, bounds.minX - 0.12),
            y: max(0, bounds.minY - 0.10),
            width: min(1 - max(0, bounds.minX - 0.12), bounds.width + 0.24),
            height: min(1 - max(0, bounds.minY - 0.10), bounds.height + 0.20)
        )
    }
}

private struct RGBASurface {
    struct Pixel {
        let r: UInt8
        let g: UInt8
        let b: UInt8

        var luma: Double {
            0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        }

        var isRedDominant: Bool {
            let gInt = Int(g)
            let bInt = Int(b)
            return r > 120 && r > gInt + 18 && r > bInt + 24
        }

        var isYellowDominant: Bool {
            let gInt = Int(g)
            let bInt = Int(b)
            return r > 140 && gInt > 110 && bInt < 110
        }

        var isBlueDominant: Bool {
            b > 100 && r < 140
        }

        var isMarioLike: Bool {
            isRedDominant || isYellowDominant
        }
    }

    let data: Data
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let size: CGSize
    let bounds: CGRect

    init(frameBufferInfo: FrameBufferInfo) {
        data = frameBufferInfo.data
        width = frameBufferInfo.width
        height = frameBufferInfo.height
        bytesPerRow = frameBufferInfo.pitch
        size = CGSize(width: width, height: height)
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
    }

    func denormalize(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    func pixel(x: Int, y: Int) -> Pixel {
        let offset = y * bytesPerRow + x * 4
        let b = data[offset]
        let g = data[offset + 1]
        let r = data[offset + 2]
        return Pixel(r: r, g: g, b: b)
    }

    func meanLuma(in rect: CGRect) -> Double {
        let clamped = rect.intersection(bounds)
        guard !clamped.isNull else { return 0 }
        var sum = 0.0
        var count = 0
        for y in stride(from: max(Int(clamped.minY), 0), to: min(Int(clamped.maxY), height), by: 2) {
            for x in stride(from: max(Int(clamped.minX), 0), to: min(Int(clamped.maxX), width), by: 2) {
                sum += pixel(x: x, y: y).luma
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        return sum / Double(count)
    }

    func lumaVariance(in rect: CGRect) -> Double {
        let mean = meanLuma(in: rect)
        let clamped = rect.intersection(bounds)
        guard !clamped.isNull else { return 0 }
        var sum = 0.0
        var count = 0
        for y in stride(from: max(Int(clamped.minY), 0), to: min(Int(clamped.maxY), height), by: 3) {
            for x in stride(from: max(Int(clamped.minX), 0), to: min(Int(clamped.maxX), width), by: 3) {
                let delta = pixel(x: x, y: y).luma - mean
                sum += delta * delta
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        return sum / Double(count)
    }
}

private extension CGRect {
    func normalized(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(
            x: min(max(minX / size.width, 0), 1),
            y: min(max(minY / size.height, 0), 1),
            width: min(max(width / size.width, 0), 1),
            height: min(max(height / size.height, 0), 1)
        )
    }
}
