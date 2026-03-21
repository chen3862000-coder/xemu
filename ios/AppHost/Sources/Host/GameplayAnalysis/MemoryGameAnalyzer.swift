import Foundation

/// Memory-based game state analyzer using known memory patterns
final class MemoryGameAnalyzer {

    // Pattern match caching to avoid repeated expensive analysis
    private var cachedPatternMatch: MarioMemoryPattern?
    private var cachedGameTitle: String = ""

    // Mario game memory patterns organized by platform
    private let marioPatterns: [MarioMemoryPattern] = [
        // Game Boy Color games
        MarioMemoryPattern(
            gameTitle: "super mario land",
            platform: .GB,
            livesAddress: 0xC0A0,
            healthAddress: 0xC0A2,
            powerUpAddress: 0xC0A4,
            levelAddress: 0xC0A6,
            scoreAddress: 0xC0A8,
            keywords: ["mario", "land"]
        ),
        MarioMemoryPattern(
            gameTitle: "super mario land 2",
            platform: .GB,
            livesAddress: 0xC0B0,
            healthAddress: 0xC0B2,
            powerUpAddress: 0xC0B4,
            levelAddress: 0xC0B6,
            scoreAddress: 0xC0B8,
            keywords: ["mario", "land", "2", "golden", "coins"]
        ),
        MarioMemoryPattern(
            gameTitle: "super mario bros deluxe",
            platform: .GBC,
            livesAddress: 0xC0C0,
            healthAddress: 0xC0C2,
            powerUpAddress: 0xC0C4,
            levelAddress: 0xC0C6,
            scoreAddress: 0xC0C8,
            keywords: ["mario", "bros", "deluxe", "smbd", "smd", "smb"]
        ),

        // Game Boy Advance games
        MarioMemoryPattern(
            gameTitle: "super mario advance",
            platform: .GBA,
            livesAddress: 0x02000000,
            healthAddress: 0x02000002,
            powerUpAddress: 0x02000004,
            levelAddress: 0x02000006,
            scoreAddress: 0x02000008,
            keywords: ["mario", "advance"]
        ),
        MarioMemoryPattern(
            gameTitle: "super mario advance 2",
            platform: .GBA,
            livesAddress: 0x02000020,
            healthAddress: 0x02000022,
            powerUpAddress: 0x02000024,
            levelAddress: 0x02000026,
            scoreAddress: 0x02000028,
            keywords: ["mario", "advance", "2", "world"]
        ),
        MarioMemoryPattern(
            gameTitle: "super mario advance 3",
            platform: .GBA,
            livesAddress: 0x02000040,
            healthAddress: 0x02000042,
            powerUpAddress: 0x02000044,
            levelAddress: 0x02000046,
            scoreAddress: 0x02000048,
            keywords: ["mario", "advance", "3", "yoshi"]
        ),
        MarioMemoryPattern(
            gameTitle: "super mario advance 4",
            platform: .GBA,
            livesAddress: 0x02000060,
            healthAddress: 0x02000062,
            powerUpAddress: 0x02000064,
            levelAddress: 0x02000066,
            scoreAddress: 0x02000068,
            keywords: ["mario", "advance", "4", "bros", "3"]
        ),
    ]

    private var previousLives: [UInt8] = []
    private var previousHealth: [UInt8] = []
    private var previousLiveSample: MarioLiveMemorySample?
    private var lastStableLiveSample: MarioLiveMemorySample?
    private var invulnerabilityWindowReported = false
    private var nonDeathEventsArmed = false

    init() {}

    func analyzeLiveMemory(
        _ liveSample: MarioLiveMemorySample,
        profile: MarioGameProfile
    ) -> MemoryGameObservation? {
        guard let memoryMap = profile.liveMemory else {
            return nil
        }
        guard let lives = liveSample.lives,
              let powerUpState = liveSample.powerUpState,
              let gameplayState = liveSample.gameplayState,
              let invulnerabilityTimer = liveSample.invulnerabilityTimer else {
            previousLiveSample = liveSample
            return nil
        }

        var currentPlayerState = playerState(
            powerUpState: powerUpState,
            gameplayState: gameplayState,
            invulnerabilityTimer: invulnerabilityTimer,
            memoryMap: memoryMap
        )
        var gameplayPhase: MarioGameplayPhase = memoryMap.deathStateValues.contains(gameplayState) ? .deathSequence : .gameplayActive
        let isInvulnerable = invulnerabilityTimer > 0 ||
            memoryMap.invulnerabilityStateValues.contains(gameplayState)

        guard let previousLiveSample else {
            self.previousLiveSample = liveSample
            if !isInvulnerable && gameplayPhase == .gameplayActive && lives > 0 {
                lastStableLiveSample = liveSample
                nonDeathEventsArmed = true
            }
            return MemoryGameObservation(
                events: [],
                confidence: 0.98,
                lives: Int(lives),
                health: 0,
                powerUp: Int(powerUpState),
                playerState: currentPlayerState,
                gameplayPhase: gameplayPhase,
                blinkConfidence: invulnerabilityTimer > 0 ? 0.85 : 0.0,
                debugSummary: debugSummary(
                    lives: lives,
                    powerUpState: powerUpState,
                    gameplayState: gameplayState,
                    invulnerabilityTimer: invulnerabilityTimer
                ),
                pattern: nil
            )
        }

        var events: [GameplayEvent] = []

        if let previousGameplayState = previousLiveSample.gameplayState,
           memoryMap.deathStateValues.contains(gameplayState),
           !memoryMap.deathStateValues.contains(previousGameplayState) {
            events.append(.deathDetected)
        } else if let previousLives = previousLiveSample.lives,
                  lives < previousLives {
            events.append(.deathDetected)
        } else if nonDeathEventsArmed,
                  let previousPowerUpState = previousLiveSample.powerUpState,
                  powerUpState < previousPowerUpState {
            events.append(.damageLight)
        } else if nonDeathEventsArmed,
                  let previousInvulnerabilityTimer = previousLiveSample.invulnerabilityTimer,
                  let previousGameplayState = previousLiveSample.gameplayState,
                  previousInvulnerabilityTimer == 0,
                  invulnerabilityTimer > 0,
                  !memoryMap.deathStateValues.contains(gameplayState),
                  memoryMap.invulnerabilityStateValues.isEmpty ||
                      memoryMap.invulnerabilityStateValues.contains(gameplayState) ||
                      memoryMap.invulnerabilityStateValues.contains(previousGameplayState) {
            events.append(.damageLight)
        } else if nonDeathEventsArmed,
                  isInvulnerable,
                  !invulnerabilityWindowReported,
                  !memoryMap.deathStateValues.contains(gameplayState),
                  let stableSample = lastStableLiveSample,
                  let stableLives = stableSample.lives,
                  let stablePowerUpState = stableSample.powerUpState,
                  stableLives == lives,
                  powerUpState <= stablePowerUpState {
            events.append(.damageLight)
        } else if nonDeathEventsArmed,
                  let previousPowerUpState = previousLiveSample.powerUpState,
                  powerUpState > previousPowerUpState {
            events.append(.powerUpCollected)
        }

        if events.contains(.deathDetected) {
            currentPlayerState = .dead
            gameplayPhase = .deathSequence
            lastStableLiveSample = nil
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        }

        if events.contains(.damageLight) && isInvulnerable {
            invulnerabilityWindowReported = true
        }

        if !isInvulnerable && gameplayPhase == .gameplayActive && lives > 0 {
            lastStableLiveSample = liveSample
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = true
        } else if gameplayPhase == .deathSequence {
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        }

        self.previousLiveSample = liveSample

        return MemoryGameObservation(
            events: events,
            confidence: 0.98,
            lives: Int(lives),
            health: 0,
            powerUp: Int(powerUpState),
            playerState: currentPlayerState,
            gameplayPhase: gameplayPhase,
            blinkConfidence: invulnerabilityTimer > 0 ? 0.95 : 0.0,
            debugSummary: debugSummary(
                lives: lives,
                powerUpState: powerUpState,
                gameplayState: gameplayState,
                invulnerabilityTimer: invulnerabilityTimer
            ),
            pattern: nil
        )
    }

    func reset() {
        cachedPatternMatch = nil
        cachedGameTitle = ""
        previousLives = []
        previousHealth = []
        previousLiveSample = nil
        lastStableLiveSample = nil
        invulnerabilityWindowReported = false
        nonDeathEventsArmed = false
    }

    /// Analyze game state using save state data
    func analyzeSaveState(_ saveStateData: Data, for platform: Platform) -> MemoryGameObservation? {
        print("🧠 Memory Analysis: Analyzing save state")
        print("   Platform: \(platform)")
        print("   Save State Size: \(saveStateData.count) bytes")

        // Try to find matching pattern for this platform
        let platformPatterns = marioPatterns.filter { $0.platform == platform }

        for pattern in platformPatterns {
            if let observation = analyzePattern(pattern, in: saveStateData) {
                print("   ✓ Matched pattern: \(pattern.gameTitle)")
                return observation
            }
        }

        print("✗ No pattern match found for platform: \(platform)")
        return nil
    }

    /// Analyze game using heuristics based on game title
    func analyzeGameUsingHeuristics(_ platform: Platform, gameTitle: String) -> MemoryGameObservation? {
        print("🔍 Memory Analysis: Attempting heuristic detection")
        print("   Platform: \(platform)")
        print("   Game Title: '\(gameTitle)'")

        // Normalize title: remove all non-alphanumeric characters
        let normalizedTitle = gameTitle.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)

        print("   Normalized title: '\(normalizedTitle)'")

        // Early rejection: if title contains "wario", skip Mario analysis completely
        if normalizedTitle.contains("wario") {
            print("   ✗ Game appears to be Wario, not Mario - skipping analysis")
            cachedPatternMatch = nil
            cachedGameTitle = gameTitle
            return nil
        }

        // For GBC games, use simple direct matching to avoid performance issues
        if platform == .GBC || platform == .GB {
            // Simple matching for GB/GBC Mario games
            if normalizedTitle.contains("marioland") {
                // Find the right Mario Land pattern
                for pattern in marioPatterns where pattern.platform == platform {
                    if pattern.gameTitle.lowercased().contains("mario land") {
                        // Check for version number match
                        let titleNumbers = normalizedTitle.filter { $0.isNumber }
                        let patternNumbers = pattern.gameTitle.lowercased().filter { $0.isNumber }

                        if !titleNumbers.isEmpty && titleNumbers == patternNumbers {
                            print("   ✓ Direct match: \(pattern.gameTitle)")
                            return createMemoryObservation(from: pattern, platform: platform)
                        }
                    }
                }
            }

            // If no Mario Land match, try Deluxe
            if normalizedTitle.contains("deluxe") || normalizedTitle.contains("mariodeluxe") {
                for pattern in marioPatterns where pattern.platform == platform {
                    if pattern.gameTitle.lowercased().contains("deluxe") {
                        print("   ✓ Direct match: \(pattern.gameTitle)")
                        return createMemoryObservation(from: pattern, platform: platform)
                    }
                }
            }

            print("   ✗ No GB/GBC Mario match found")
            return nil
        }

        // For GBA games, use the existing scoring system
        // Try to find matching pattern with flexible matching
        var bestMatch: MarioMemoryPattern?
        var bestScore = 0

        for pattern in marioPatterns {
            // Skip if platform doesn't match
            if pattern.platform != platform {
                continue
            }

            // Simple keyword matching
            var matchScore = 0

            for keyword in pattern.keywords {
                if normalizedTitle.contains(keyword.lowercased()) {
                    matchScore += 20  // Fixed points per keyword
                    print("   ✓ Keyword match: '\(keyword)' in title (+20 points)")
                }
            }

            // Update best match if current pattern scores higher
            if matchScore > bestScore && matchScore >= 30 {
                bestScore = matchScore
                bestMatch = pattern
                print("   📊 Pattern '\(pattern.gameTitle)' score: \(matchScore)%")
            }
        }

        // Return best match if found
        if let bestMatch = bestMatch {
            print("   ✓ Best matched pattern: \(bestMatch.gameTitle) with \(bestScore)% confidence")
            return createMemoryObservation(from: bestMatch, platform: platform)
        }

        print("✗ No suitable pattern match found")
        return nil
    }

    /// Analyze a specific pattern in save state data
    private func analyzePattern(_ pattern: MarioMemoryPattern, in saveStateData: Data) -> MemoryGameObservation? {
        var events: [GameplayEvent] = []

        // Read lives value
        var currentLives: UInt8 = 0
        if pattern.livesAddress < UInt32(saveStateData.count) {
            currentLives = saveStateData[Int(pattern.livesAddress)]
        }

        // Read health value
        var currentHealth: UInt8 = 0
        if pattern.healthAddress < UInt32(saveStateData.count) {
            currentHealth = saveStateData[Int(pattern.healthAddress)]
        }

        // Read power-up value
        var currentPowerUp: UInt8 = 0
        if pattern.powerUpAddress < UInt32(saveStateData.count) {
            currentPowerUp = saveStateData[Int(pattern.powerUpAddress)]
        }

        // Track previous values for change detection
        let livesIndex = Int(pattern.livesAddress % 256) // Use address as index
        let healthIndex = Int(pattern.healthAddress % 256)

        // Initialize previous values arrays if needed
        while previousLives.count <= livesIndex {
            previousLives.append(0)
        }
        while previousHealth.count <= healthIndex {
            previousHealth.append(0)
        }

        // Detect life loss
        let previousLivesValue = previousLives[livesIndex]
        if currentLives < previousLivesValue && previousLivesValue > 0 {
            events.append(.deathDetected)
            print("   💀 Life loss detected: \(previousLivesValue) → \(currentLives)")
        }

        // Detect health loss
        let previousHealthValue = previousHealth[healthIndex]
        if currentHealth < previousHealthValue && previousHealthValue > 0 {
            let damageSeverity: GameplayEvent = (previousHealthValue - currentHealth) > 2 ? .damageHeavy : .damageLight
            events.append(damageSeverity)
            print("   💔 Health loss detected: \(previousHealthValue) → \(currentHealth)")
        }

        // Detect power-up collection
        if currentPowerUp > 0 && previousHealth[healthIndex] == 0 {
            events.append(.powerUpCollected)
            print("   ⭐ Power-up detected")
        }

        // Store current values for next comparison
        previousLives[livesIndex] = currentLives
        previousHealth[healthIndex] = currentHealth

        // Calculate confidence based on memory address validity
        let confidence = (pattern.livesAddress < UInt32(saveStateData.count) &&
                         pattern.healthAddress < UInt32(saveStateData.count)) ? 0.95 : 0.75

        return MemoryGameObservation(
            events: events,
            confidence: confidence,
            lives: Int(currentLives),
            health: Int(currentHealth),
            powerUp: Int(currentPowerUp),
            playerState: .unknown,
            gameplayPhase: .unknown,
            blinkConfidence: 0.0,
            debugSummary: nil,
            pattern: pattern
        )
    }

    /// Create memory observation from pattern without save state data
    private func createMemoryObservation(from pattern: MarioMemoryPattern, platform: Platform) -> MemoryGameObservation {
        // Without actual save state data, we can't detect state changes
        // But we can return high confidence that this is the right pattern
        return MemoryGameObservation(
            events: [],
            confidence: 0.85,
            lives: 0,
            health: 0,
            powerUp: 0,
            playerState: .unknown,
            gameplayPhase: .unknown,
            blinkConfidence: 0.0,
            debugSummary: nil,
            pattern: pattern
        )
    }

    private func playerState(
        powerUpState: UInt8,
        gameplayState: UInt8,
        invulnerabilityTimer: UInt8,
        memoryMap: MarioLiveMemoryMap
    ) -> MarioPlayerState {
        if memoryMap.deathStateValues.contains(gameplayState) {
            return .dead
        }
        if invulnerabilityTimer > 0 ||
            memoryMap.invulnerabilityStateValues.contains(gameplayState) {
            if memoryMap.smallPowerUpValues.contains(powerUpState) {
                return .invulnerableBlink
            }
            if memoryMap.superPowerUpValues.contains(powerUpState) {
                return .superState
            }
            if memoryMap.poweredUpValues.contains(powerUpState) {
                return .poweredUp
            }
            return .invulnerableBlink
        }
        if memoryMap.smallPowerUpValues.contains(powerUpState) {
            return .small
        }
        if memoryMap.superPowerUpValues.contains(powerUpState) {
            return .superState
        }
        if memoryMap.poweredUpValues.contains(powerUpState) {
            return .poweredUp
        }
        return .unknown
    }

    private func debugSummary(
        lives: UInt8,
        powerUpState: UInt8,
        gameplayState: UInt8,
        invulnerabilityTimer: UInt8
    ) -> String {
        String(
            format: "mem L=%u P=%u S=%02X I=%u",
            Int(lives),
            Int(powerUpState),
            Int(gameplayState),
            Int(invulnerabilityTimer)
        )
    }
}

/// Mario game memory pattern
struct MarioMemoryPattern {
    let gameTitle: String
    let platform: Platform
    let livesAddress: UInt32
    let healthAddress: UInt32
    let powerUpAddress: UInt32
    let levelAddress: UInt32
    let scoreAddress: UInt32
    let keywords: [String]
}

/// Memory game observation result
struct MemoryGameObservation {
    let events: [GameplayEvent]
    let confidence: Double
    let lives: Int
    let health: Int
    let powerUp: Int
    let playerState: MarioPlayerState
    let gameplayPhase: MarioGameplayPhase
    let blinkConfidence: Double
    let debugSummary: String?
    let pattern: MarioMemoryPattern?
}
