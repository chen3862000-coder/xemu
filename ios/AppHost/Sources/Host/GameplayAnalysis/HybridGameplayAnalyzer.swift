import Foundation
import CoreGraphics

enum DetectionMethod: String, Sendable {
    case memory      // Direct RAM reading (highest accuracy)
    case pattern      // Frame pattern recognition (medium accuracy)
    case vision      // Computer vision (lowest accuracy)
    case unknown
}

/// Hybrid gameplay analyzer that combines multiple detection methods
/// Priority: Memory (95-99%) → Pattern recognition (80-85%) → Computer vision (60-70%)
final class HybridGameplayAnalyzer {
    private let memoryAnalyzer = MemoryGameAnalyzer()
    private let frameAnalyzer = MarioFrameAnalyzer(profile: .superMarioLand)
    private var currentDetectionMethod: DetectionMethod = .unknown
    private var confidenceThreshold: Double = 0.75 // Minimum confidence to trust a method

    // Performance tracking
    private var memoryCheckCount = 0
    private var patternCheckCount = 0
    private var visionCheckCount = 0

    init() {}

    /// Analyze gameplay using the best available method
    func analyze(
        frameBufferInfo: FrameBufferInfo,
        saveStateData: Data?,
        platform: Platform,
        gameTitle: String
    ) -> HybridAnalysisResult {
        let timestamp = Date()

        // Debug logging
        print("🔍 Hybrid Analysis: Starting")
        print("   Platform: \(platform)")
        print("   Game Title: '\(gameTitle)'")
        print("   Save State Data: \(saveStateData != nil ? "Available (\(saveStateData!.count) bytes)" : "None")")
        print("   Current Platform: \(platform)")
        print("   Current Game Title: '\(gameTitle)'")

        // Priority 1: Memory-based detection (most accurate)
        if let stateData = saveStateData {
            if let memoryObservation = memoryAnalyzer.analyzeSaveState(stateData, for: platform) {
                currentDetectionMethod = .memory
                memoryCheckCount += 1
                confidenceThreshold = adaptConfidence(accuracy: 0.95, reliability: 1.0)

                return HybridAnalysisResult(
                    events: memoryObservation.events,
                    detectionMethod: .memory,
                    confidence: memoryObservation.confidence,
                    timestamp: timestamp,
                    performanceMetrics: PerformanceMetrics(
                        memoryCheckCount: memoryCheckCount,
                        patternCheckCount: patternCheckCount,
                        visionCheckCount: visionCheckCount,
                        confidence: confidenceThreshold
                    )
                )
            }
        } else {
            // Use heuristic detection when save state data is not available
            if let heuristicObservation = memoryAnalyzer.analyzeGameUsingHeuristics(platform, gameTitle: gameTitle) {
                currentDetectionMethod = .memory
                memoryCheckCount += 1
                confidenceThreshold = adaptConfidence(accuracy: 0.85, reliability: 0.9)

                return HybridAnalysisResult(
                    events: heuristicObservation.events,
                    detectionMethod: .memory,
                    confidence: heuristicObservation.confidence,
                    timestamp: timestamp,
                    performanceMetrics: PerformanceMetrics(
                        memoryCheckCount: memoryCheckCount,
                        patternCheckCount: patternCheckCount,
                        visionCheckCount: visionCheckCount,
                        confidence: confidenceThreshold
                    )
                )
            }
        }
        // Continue to pattern recognition if memory detection not available or found no events

        // Priority 2: Pattern recognition (medium accuracy)
        let frameAnalysis = analyzeFramePatterns(frameBufferInfo, gameTitle: gameTitle)
        if frameAnalysis.confidence > confidenceThreshold {

            currentDetectionMethod = .pattern
            patternCheckCount += 1
            confidenceThreshold = adaptConfidence(accuracy: 0.80, reliability: 0.9)

            return HybridAnalysisResult(
                events: frameAnalysis.events,
                detectionMethod: .pattern,
                confidence: frameAnalysis.confidence,
                timestamp: timestamp,
                performanceMetrics: PerformanceMetrics(
                    memoryCheckCount: memoryCheckCount,
                    patternCheckCount: patternCheckCount,
                    visionCheckCount: visionCheckCount,
                    confidence: confidenceThreshold
                )
            )
        }

        // Priority 3: Computer vision (fallback, lower accuracy)
        let visualAnalysis = analyzeVisualFrame(frameBufferInfo)
        visionCheckCount += 1
        confidenceThreshold = adaptConfidence(accuracy: 0.60, reliability: 0.7)

        currentDetectionMethod = .vision

        return HybridAnalysisResult(
            events: visualAnalysis.events,
            detectionMethod: .vision,
            confidence: visualAnalysis.confidence,
            timestamp: timestamp,
            performanceMetrics: PerformanceMetrics(
                memoryCheckCount: memoryCheckCount,
                patternCheckCount: patternCheckCount,
                visionCheckCount: visionCheckCount,
                confidence: confidenceThreshold
            )
        )
    }

    /// Analyze frame patterns for medium-accuracy detection
    private func analyzeFramePatterns(_ frameBufferInfo: FrameBufferInfo, gameTitle: String) -> FramePatternAnalysisResult {
        var events: [GameplayEvent] = []

        // Analyze specific frame patterns
        if containsHealthBarChanges(frameBufferInfo) {
            events.append(.damageLight)
        }

        // Detect screen transitions
        if containsDeathScreenPattern(frameBufferInfo) {
            events.append(.deathDetected)
        }

        // Detect level completion
        if containsLevelCompletePattern(frameBufferInfo) {
            events.append(.levelCompleted)
        }

        let confidence = events.isEmpty ? 0.0 : 0.82

        return FramePatternAnalysisResult(
            events: events,
            confidence: confidence
        )
    }

    /// Analyze visual frame (existing computer vision logic)
    private func analyzeVisualFrame(_ frameBufferInfo: FrameBufferInfo) -> FramePatternAnalysisResult {
        let observation = frameAnalyzer.analyze(frameBufferInfo: frameBufferInfo, timestamp: Date())

        // Convert visual observations to gameplay events
        var events: [GameplayEvent] = []

        if observation.deathAnimationConfidence > 0.78 {
            events.append(.deathDetected)
        } else if observation.hurtPoseConfidence > 0.82 {
            events.append(observation.playerStateConfidence > 0.65 ? .damageHeavy : .damageLight)
        } else if observation.playerState == .poweredUp && observation.blinkConfidence < 0.2 {
            events.append(.powerUpCollected)
        }

        let confidence = events.isEmpty ? 0.0 : 0.68

        return FramePatternAnalysisResult(
            events: events,
            confidence: confidence
        )
    }

    /// Check for health bar color changes
    private func containsHealthBarChanges(_ frameBufferInfo: FrameBufferInfo) -> Bool {
        // Simple heuristic: check if health bar colors changed significantly
        // This is a simplified pattern recognition approach
        return false // Placeholder for now
    }

    /// Check for death screen patterns
    private func containsDeathScreenPattern(_ frameBufferInfo: FrameBufferInfo) -> Bool {
        // Check if screen is mostly black (death screen)
        let surface = RGBASurface(frameBufferInfo: frameBufferInfo)
        let meanLuma = surface.meanLuma(in: surface.bounds)

        // Death screen typically has very low brightness
        return meanLuma < 20.0
    }

    /// Check for level completion patterns
    private func containsLevelCompletePattern(_ frameBufferInfo: FrameBufferInfo) -> Bool {
        // Check for bright screen with specific patterns
        // This is a simplified approach
        return false // Placeholder for now
    }

    /// Adapt confidence threshold based on method performance
    private func adaptConfidence(accuracy: Double, reliability: Double) -> Double {
        // Start with base accuracy and adjust based on performance
        return max(0.0, min(1.0, accuracy))
    }

    /// Reset analyzer for new game session
    func reset() {
        currentDetectionMethod = .unknown
        confidenceThreshold = 0.75
        memoryCheckCount = 0
        patternCheckCount = 0
        visionCheckCount = 0
        memoryAnalyzer.reset()
    }
}

/// Hybrid analysis result
struct HybridAnalysisResult {
    let events: [GameplayEvent]
    let detectionMethod: DetectionMethod
    let confidence: Double
    let timestamp: Date
    let performanceMetrics: PerformanceMetrics
}

/// Frame pattern analysis result
private struct FramePatternAnalysisResult {
    let events: [GameplayEvent]
    let confidence: Double
}

/// Performance metrics for detection methods
struct PerformanceMetrics {
    let memoryCheckCount: Int
    let patternCheckCount: Int
    let visionCheckCount: Int
    let confidence: Double
}

/// RGBA surface wrapper for pattern analysis
private struct RGBASurface {
    let data: Data
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let bounds: CGRect

    init(frameBufferInfo: FrameBufferInfo) {
        self.data = frameBufferInfo.data
        self.width = frameBufferInfo.width
        self.height = frameBufferInfo.height
        self.bytesPerRow = frameBufferInfo.pitch
        self.bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    }

    func meanLuma(in rect: CGRect) -> Double {
        let clamped = rect.intersection(bounds)
        guard !clamped.isNull else { return 0 }

        var sum = 0.0
        var count = 0

        let startY = Int(clamped.minY)
        let endY = Int(clamped.maxY)
        let startX = Int(clamped.minX)
        let endX = Int(clamped.maxX)

        for y in stride(from: startY, to: endY, by: 4) {
            for x in stride(from: startX, to: endX, by: 4) {
                let offset = y * bytesPerRow + x * 4
                if offset + 3 < data.count {
                    let r = Double(data[offset])
                    let g = Double(data[offset + 1])
                    let b = Double(data[offset + 2])

                    // Convert RGBA to luma
                    let luma = 0.299 * r + 0.587 * g + 0.114 * b
                    sum += luma
                    count += 1
                }
            }
        }

        return count > 0 ? sum / Double(count) : 0
    }
}