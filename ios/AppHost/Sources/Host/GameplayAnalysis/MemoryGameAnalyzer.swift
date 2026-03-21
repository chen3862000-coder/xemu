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

        if memoryMap.kind == .metroidFusion {
            return analyzeMetroidFusionLiveMemory(liveSample, memoryMap: memoryMap)
        }
        if memoryMap.kind == .dragonBallAdvancedAdventure {
            return analyzeDragonBallAdvancedAdventureLiveMemory(liveSample, memoryMap: memoryMap)
        }
        if memoryMap.kind == .castlevaniaAriaOfSorrow {
            return analyzeCastlevaniaAriaOfSorrowLiveMemory(liveSample, memoryMap: memoryMap)
        }
        if memoryMap.kind == .castlevaniaCircleOfTheMoon {
            return analyzeCastlevaniaCircleOfTheMoonLiveMemory(liveSample, memoryMap: memoryMap)
        }
        if memoryMap.kind == .castlevaniaHarmonyOfDissonance {
            return analyzeCastlevaniaHarmonyOfDissonanceLiveMemory(liveSample, memoryMap: memoryMap)
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
                locationSummary: marioLocationSummary(for: profile, liveSample: liveSample),
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
            locationSummary: marioLocationSummary(for: profile, liveSample: liveSample),
            pattern: nil
        )
    }

    private func analyzeMetroidFusionLiveMemory(
        _ liveSample: MarioLiveMemorySample,
        memoryMap: MarioLiveMemoryMap
    ) -> MemoryGameObservation? {
        guard let health = liveSample.health,
              let maxHealth = liveSample.maxHealth,
              let suitStatus = liveSample.powerUpState,
              let pose = liveSample.gameplayState,
              let invulnerabilityTimer = liveSample.invulnerabilityTimer,
              let gameMode = liveSample.gameMode else {
            previousLiveSample = liveSample
            return nil
        }

        let isDeathMode = memoryMap.deathStateValues.contains(pose) || gameMode == 0x08 || gameMode == 0x0A || health == 0
        let isGameplayActive = gameMode == 0x01
        let isInvulnerable = invulnerabilityTimer > 0 || memoryMap.invulnerabilityStateValues.contains(pose)

        var playerState: MarioPlayerState
        if isDeathMode {
            playerState = .dead
        } else if isInvulnerable {
            playerState = .invulnerableBlink
        } else if suitStatus == 0 {
            playerState = .superState
        } else {
            playerState = .poweredUp
        }

        let gameplayPhase: MarioGameplayPhase = isDeathMode ? .deathSequence : (isGameplayActive ? .gameplayActive : .transition)

        guard let previousLiveSample else {
            self.previousLiveSample = liveSample
            if isGameplayActive && !isInvulnerable && health > 0 {
                lastStableLiveSample = liveSample
                nonDeathEventsArmed = true
            }
            return MemoryGameObservation(
                events: [],
                confidence: 0.98,
                lives: Int(maxHealth),
                health: Int(health),
                powerUp: Int(suitStatus),
                playerState: playerState,
                gameplayPhase: gameplayPhase,
                blinkConfidence: isInvulnerable ? 0.90 : 0.0,
                debugSummary: metroidDebugSummary(
                    health: health,
                    maxHealth: maxHealth,
                    suitStatus: suitStatus,
                    pose: pose,
                    invulnerabilityTimer: invulnerabilityTimer,
                    gameMode: gameMode
                ),
                locationSummary: metroidLocationSummary(liveSample: liveSample),
                pattern: nil
            )
        }

        var events: [GameplayEvent] = []
        let previousHealth = previousLiveSample.health
        let previousPose = previousLiveSample.gameplayState
        let previousGameMode = previousLiveSample.gameMode

        let previousWasDeath = previousPose.map(memoryMap.deathStateValues.contains) == true ||
            previousGameMode == 0x08 ||
            previousGameMode == 0x0A ||
            previousHealth == 0

        if isDeathMode && !previousWasDeath {
            events.append(.deathDetected)
        } else if nonDeathEventsArmed,
                  isGameplayActive,
                  let previousHealth,
                  previousHealth > health,
                  health > 0 {
            let healthDelta = previousHealth - health
            events.append(healthDelta >= 30 ? .damageHeavy : .damageLight)
        }

        if events.contains(.deathDetected) {
            lastStableLiveSample = nil
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        }

        if isGameplayActive && !isInvulnerable && health > 0 {
            lastStableLiveSample = liveSample
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = true
        } else if isDeathMode || !isGameplayActive {
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        }

        self.previousLiveSample = liveSample

        return MemoryGameObservation(
            events: events,
            confidence: 0.98,
            lives: Int(maxHealth),
            health: Int(health),
            powerUp: Int(suitStatus),
            playerState: playerState,
            gameplayPhase: gameplayPhase,
            blinkConfidence: isInvulnerable ? 0.95 : 0.0,
            debugSummary: metroidDebugSummary(
                health: health,
                maxHealth: maxHealth,
                suitStatus: suitStatus,
                pose: pose,
                invulnerabilityTimer: invulnerabilityTimer,
                gameMode: gameMode
            ),
            locationSummary: metroidLocationSummary(liveSample: liveSample),
            pattern: nil
        )
    }

    private func analyzeCastlevaniaAriaOfSorrowLiveMemory(
        _ liveSample: MarioLiveMemorySample,
        memoryMap: MarioLiveMemoryMap
    ) -> MemoryGameObservation? {
        guard let health = liveSample.health,
              let maxHealth = liveSample.maxHealth,
              let equipmentState = liveSample.powerUpState,
              let movementState = liveSample.gameplayState,
              let timer = liveSample.invulnerabilityTimer,
              let gameMode = liveSample.gameMode else {
            previousLiveSample = liveSample
            return nil
        }

        let isDeathState = memoryMap.deathStateValues.contains(movementState) || gameMode == 0x05 || health == 0
        let isGameplayActive = gameMode == 0x04
        let isInvulnerable = memoryMap.invulnerabilityStateValues.contains(movementState) || timer > 0

        let playerState: MarioPlayerState
        if isDeathState {
            playerState = .dead
        } else if isInvulnerable {
            playerState = .invulnerableBlink
        } else if equipmentState == 0 {
            playerState = .superState
        } else {
            playerState = .poweredUp
        }

        let gameplayPhase: MarioGameplayPhase = isDeathState ? .deathSequence : (isGameplayActive ? .gameplayActive : .transition)

        guard let previousLiveSample else {
            self.previousLiveSample = liveSample
            if isGameplayActive && !isInvulnerable && health > 0 {
                lastStableLiveSample = liveSample
                nonDeathEventsArmed = true
            }
            return MemoryGameObservation(
                events: [],
                confidence: 0.98,
                lives: Int(maxHealth),
                health: Int(health),
                powerUp: Int(equipmentState),
                playerState: playerState,
                gameplayPhase: gameplayPhase,
                blinkConfidence: isInvulnerable ? 0.90 : 0.0,
                debugSummary: castlevaniaDebugSummary(
                    health: health,
                    maxHealth: maxHealth,
                    movementState: movementState,
                    timer: timer,
                    gameMode: gameMode
                ),
                locationSummary: castlevaniaAriaLocationSummary(liveSample: liveSample),
                pattern: nil
            )
        }

        let previousHealth = previousLiveSample.health
        let previousMovementState = previousLiveSample.gameplayState
        let previousGameMode = previousLiveSample.gameMode
        let previousWasDeath = previousMovementState.map(memoryMap.deathStateValues.contains) == true ||
            previousGameMode == 0x05 ||
            previousHealth == 0

        var events: [GameplayEvent] = []
        if isDeathState && !previousWasDeath {
            events.append(.deathDetected)
        } else if nonDeathEventsArmed,
                  isGameplayActive,
                  let previousHealth,
                  previousHealth > health,
                  health > 0 {
            let delta = previousHealth - health
            events.append(delta >= 20 ? .damageHeavy : .damageLight)
        }

        if events.contains(.deathDetected) {
            lastStableLiveSample = nil
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        }

        if isGameplayActive && !isInvulnerable && health > 0 {
            lastStableLiveSample = liveSample
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = true
        } else if isDeathState || !isGameplayActive {
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        }

        self.previousLiveSample = liveSample

        return MemoryGameObservation(
            events: events,
            confidence: 0.98,
            lives: Int(maxHealth),
            health: Int(health),
            powerUp: Int(equipmentState),
            playerState: playerState,
            gameplayPhase: gameplayPhase,
            blinkConfidence: isInvulnerable ? 0.95 : 0.0,
            debugSummary: castlevaniaDebugSummary(
                health: health,
                maxHealth: maxHealth,
                movementState: movementState,
                timer: timer,
                gameMode: gameMode
            ),
            locationSummary: castlevaniaAriaLocationSummary(liveSample: liveSample),
            pattern: nil
        )
    }

    private func analyzeDragonBallAdvancedAdventureLiveMemory(
        _ liveSample: MarioLiveMemorySample,
        memoryMap: MarioLiveMemoryMap
    ) -> MemoryGameObservation? {
        guard let lives = liveSample.lives,
              let state = liveSample.gameplayState,
              let timer = liveSample.invulnerabilityTimer,
              let health = liveSample.health,
              let maxHealth = liveSample.maxHealth else {
            previousLiveSample = liveSample
            return nil
        }

        let isDeathState = health == 0
        let playerState: MarioPlayerState = isDeathState ? .dead : .superState
        let gameplayPhase: MarioGameplayPhase = isDeathState ? .deathSequence : .gameplayActive

        guard let previousLiveSample else {
            self.previousLiveSample = liveSample
            if health > 0 && lives > 0 {
                lastStableLiveSample = liveSample
                nonDeathEventsArmed = true
            }
            return MemoryGameObservation(
                events: [],
                confidence: 0.98,
                lives: Int(lives),
                health: Int(health),
                powerUp: 0,
                playerState: playerState,
                gameplayPhase: gameplayPhase,
                blinkConfidence: 0.0,
                debugSummary: dragonBallDebugSummary(
                    lives: lives,
                    state: state,
                    timer: timer,
                    health: health,
                    maxHealth: maxHealth
                ),
                locationSummary: nil,
                pattern: nil
            )
        }

        let previousHealth = previousLiveSample.health
        let previousLives = previousLiveSample.lives
        let previousState = previousLiveSample.gameplayState
        let previousTimer = previousLiveSample.invulnerabilityTimer
        let previousWasDeath = previousHealth == 0

        var events: [GameplayEvent] = []
        if isDeathState && !previousWasDeath {
            events.append(.deathDetected)
        } else if let previousLives,
                  lives < previousLives {
            events.append(.deathDetected)
        } else if nonDeathEventsArmed,
                  let previousHealth,
                  previousHealth > health,
                  health > 0 {
            let delta = previousHealth - health
            events.append(delta >= 32 ? .damageHeavy : .damageLight)
        } else if nonDeathEventsArmed,
                  health > 0,
                  (previousState ?? 0) == 0,
                  state != 0 || timer != 0,
                  (previousTimer ?? 0) == 0 {
            events.append(.damageLight)
        }

        if events.contains(.deathDetected) {
            lastStableLiveSample = nil
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        } else if health > 0 && lives > 0 {
            lastStableLiveSample = liveSample
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = true
        }

        self.previousLiveSample = liveSample

        return MemoryGameObservation(
            events: events,
            confidence: 0.98,
            lives: Int(lives),
            health: Int(health),
            powerUp: 0,
            playerState: playerState,
            gameplayPhase: gameplayPhase,
            blinkConfidence: 0.0,
            debugSummary: dragonBallDebugSummary(
                lives: lives,
                state: state,
                timer: timer,
                health: health,
                maxHealth: maxHealth
            ),
            locationSummary: nil,
            pattern: nil
        )
    }

    private func analyzeCastlevaniaCircleOfTheMoonLiveMemory(
        _ liveSample: MarioLiveMemorySample,
        memoryMap: MarioLiveMemoryMap
    ) -> MemoryGameObservation? {
        guard let health = liveSample.health,
              let maxHealth = liveSample.maxHealth,
              let equipmentState = liveSample.powerUpState,
              let movementState = liveSample.gameplayState,
              let timer = liveSample.invulnerabilityTimer else {
            previousLiveSample = liveSample
            return nil
        }

        let isDeathState = health == 0
        let isInvulnerable = timer > 0 || memoryMap.invulnerabilityStateValues.contains(movementState)
        let playerState: MarioPlayerState = isDeathState ? .dead : (isInvulnerable ? .invulnerableBlink : (equipmentState == 0 ? .superState : .poweredUp))
        let gameplayPhase: MarioGameplayPhase = isDeathState ? .deathSequence : .gameplayActive

        guard let previousLiveSample else {
            self.previousLiveSample = liveSample
            if !isInvulnerable && health > 0 {
                lastStableLiveSample = liveSample
                nonDeathEventsArmed = true
            }
            return MemoryGameObservation(
                events: [],
                confidence: 0.98,
                lives: Int(maxHealth),
                health: Int(health),
                powerUp: Int(equipmentState),
                playerState: playerState,
                gameplayPhase: gameplayPhase,
                blinkConfidence: isInvulnerable ? 0.90 : 0.0,
                debugSummary: castlevaniaDebugSummary(
                    health: health,
                    maxHealth: maxHealth,
                    movementState: movementState,
                    timer: timer,
                    gameMode: nil
                ),
                locationSummary: castlevaniaCircleLocationSummary(liveSample: liveSample),
                pattern: nil
            )
        }

        var events: [GameplayEvent] = []
        if health == 0 && previousLiveSample.health != 0 {
            events.append(.deathDetected)
        } else if nonDeathEventsArmed,
                  let previousHealth = previousLiveSample.health,
                  previousHealth > health,
                  health > 0 {
            let delta = previousHealth - health
            events.append(delta >= 20 ? .damageHeavy : .damageLight)
        }

        if events.contains(.deathDetected) {
            lastStableLiveSample = nil
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = false
        } else if !isInvulnerable && health > 0 {
            lastStableLiveSample = liveSample
            invulnerabilityWindowReported = false
            nonDeathEventsArmed = true
        }

        self.previousLiveSample = liveSample

        return MemoryGameObservation(
            events: events,
            confidence: 0.98,
            lives: Int(maxHealth),
            health: Int(health),
            powerUp: Int(equipmentState),
            playerState: playerState,
            gameplayPhase: gameplayPhase,
            blinkConfidence: isInvulnerable ? 0.95 : 0.0,
            debugSummary: castlevaniaDebugSummary(
                health: health,
                maxHealth: maxHealth,
                movementState: movementState,
                timer: timer,
                gameMode: nil
            ),
            locationSummary: castlevaniaCircleLocationSummary(liveSample: liveSample),
            pattern: nil
        )
    }

    private func analyzeCastlevaniaHarmonyOfDissonanceLiveMemory(
        _ liveSample: MarioLiveMemorySample,
        memoryMap: MarioLiveMemoryMap
    ) -> MemoryGameObservation? {
        guard let health = liveSample.health,
              let maxHealth = liveSample.maxHealth,
              let spellBook = liveSample.powerUpState,
              let pseudoState = liveSample.gameplayState,
              let mpOrTimer = liveSample.invulnerabilityTimer else {
            previousLiveSample = liveSample
            return nil
        }

        let isDeathState = health == 0
        let playerState: MarioPlayerState = isDeathState ? .dead : (spellBook == 0 ? .superState : .poweredUp)
        let gameplayPhase: MarioGameplayPhase = isDeathState ? .deathSequence : .gameplayActive

        guard let previousLiveSample else {
            self.previousLiveSample = liveSample
            if health > 0 {
                lastStableLiveSample = liveSample
                nonDeathEventsArmed = true
            }
            return MemoryGameObservation(
                events: [],
                confidence: 0.96,
                lives: Int(maxHealth),
                health: Int(health),
                powerUp: Int(spellBook),
                playerState: playerState,
                gameplayPhase: gameplayPhase,
                blinkConfidence: 0.0,
                debugSummary: castlevaniaDebugSummary(
                    health: health,
                    maxHealth: maxHealth,
                    movementState: pseudoState,
                    timer: mpOrTimer,
                    gameMode: nil
                ),
                locationSummary: castlevaniaHarmonyLocationSummary(liveSample: liveSample),
                pattern: nil
            )
        }

        var events: [GameplayEvent] = []
        if health == 0 && previousLiveSample.health != 0 {
            events.append(.deathDetected)
        } else if nonDeathEventsArmed,
                  let previousHealth = previousLiveSample.health,
                  previousHealth > health,
                  health > 0 {
            let delta = previousHealth - health
            events.append(delta >= 20 ? .damageHeavy : .damageLight)
        }

        if events.contains(.deathDetected) {
            lastStableLiveSample = nil
            nonDeathEventsArmed = false
        } else if health > 0 {
            lastStableLiveSample = liveSample
            nonDeathEventsArmed = true
        }

        self.previousLiveSample = liveSample

        return MemoryGameObservation(
            events: events,
            confidence: 0.96,
            lives: Int(maxHealth),
            health: Int(health),
            powerUp: Int(spellBook),
            playerState: playerState,
            gameplayPhase: gameplayPhase,
            blinkConfidence: 0.0,
            debugSummary: castlevaniaDebugSummary(
                health: health,
                maxHealth: maxHealth,
                movementState: pseudoState,
                timer: mpOrTimer,
                gameMode: nil
            ),
            locationSummary: castlevaniaHarmonyLocationSummary(liveSample: liveSample),
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
            locationSummary: nil,
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
            locationSummary: nil,
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

    private func metroidDebugSummary(
        health: UInt16,
        maxHealth: UInt16,
        suitStatus: UInt8,
        pose: UInt8,
        invulnerabilityTimer: UInt8,
        gameMode: UInt8
    ) -> String {
        String(
            format: "mem H=%u/%u U=%02X P=%02X I=%u M=%02X",
            Int(health),
            Int(maxHealth),
            Int(suitStatus),
            Int(pose),
            Int(invulnerabilityTimer),
            Int(gameMode)
        )
    }

    private func castlevaniaDebugSummary(
        health: UInt16,
        maxHealth: UInt16,
        movementState: UInt8,
        timer: UInt8,
        gameMode: UInt8?
    ) -> String {
        String(
            format: "mem H=%u/%u M=%02X T=%u G=%02X",
            Int(health),
            Int(maxHealth),
            Int(movementState),
            Int(timer),
            Int(gameMode ?? 0)
        )
    }

    private func dragonBallDebugSummary(
        lives: UInt8,
        state: UInt8,
        timer: UInt8,
        health: UInt16,
        maxHealth: UInt16
    ) -> String {
        String(
            format: "mem L=%u S=%02X I=%u H=%u/%u",
            Int(lives),
            Int(state),
            Int(timer),
            Int(health),
            Int(maxHealth)
        )
    }

    private func marioLocationSummary(for profile: MarioGameProfile, liveSample: MarioLiveMemorySample) -> String? {
        switch profile.id {
        case MarioGameProfile.sma2SuperMarioWorld.id:
            guard let map = liveSample.contextValues["map"],
                  let level = liveSample.contextValues["level"] else {
                return nil
            }
            return "Loc \(sma2MapName(UInt8(map))) • level \(hex8(level))"
        case MarioGameProfile.sma4SuperMarioBros3.id:
            guard let world = liveSample.contextValues["world"] else {
                return nil
            }
            let mapX = liveSample.contextValues["mapX"].map(String.init) ?? "?"
            let mapY = liveSample.contextValues["mapY"].map(String.init) ?? "?"
            return "Loc \(sma4WorldName(UInt8(world))) • map \(mapX),\(mapY)"
        default:
            return nil
        }
    }

    private func metroidLocationSummary(liveSample: MarioLiveMemorySample) -> String? {
        guard let area = liveSample.contextValues["area"],
              let room = liveSample.contextValues["room"] else {
            return nil
        }
        let mapX = liveSample.contextValues["mapX"].map(String.init) ?? "?"
        let mapY = liveSample.contextValues["mapY"].map(String.init) ?? "?"
        return "Loc \(metroidAreaName(UInt8(area))) • room \(hex8(room)) • map \(mapX),\(mapY)"
    }

    private func castlevaniaAriaLocationSummary(liveSample: MarioLiveMemorySample) -> String? {
        guard let gameMode = liveSample.gameMode else { return nil }
        let subMode = liveSample.contextValues["subMode"].map { hex8($0) } ?? "--"
        let movement = liveSample.gameplayState.map(castlevaniaAriaMovementName(_:)) ?? "Unknown"
        let visitedAreas = liveSample.contextValues["visitedAreas"].map { String($0.nonzeroBitCount) } ?? "?"
        return "State \(ariaModeName(gameMode))/\(subMode) • \(movement) • areas \(visitedAreas)"
    }

    private func castlevaniaCircleLocationSummary(liveSample: MarioLiveMemorySample) -> String? {
        guard let level = liveSample.contextValues["level"] else { return nil }
        return "State level \(hex8(level)) • \(circleStateName(liveSample.gameplayState))"
    }

    private func castlevaniaHarmonyLocationSummary(liveSample: MarioLiveMemorySample) -> String? {
        let visitedAreas = liveSample.contextValues["visitedAreas"].map { String($0.nonzeroBitCount) } ?? "?"
        let level = liveSample.contextValues["level"].map(hex8(_:)) ?? "--"
        return "State level \(level) • areas \(visitedAreas)"
    }

    private func sma2MapName(_ value: UInt8) -> String {
        switch value {
        case 0x00: return "Yoshi's Island"
        case 0x01: return "Donut Plains"
        case 0x02: return "Vanilla Dome"
        case 0x03: return "Twin Bridges"
        case 0x04: return "Forest of Illusion"
        case 0x05: return "Chocolate Island"
        case 0x06: return "Valley of Bowser"
        case 0x07: return "Star Road"
        case 0x08: return "Special Zone"
        default: return "Map \(hex8(UInt16(value)))"
        }
    }

    private func sma4WorldName(_ value: UInt8) -> String {
        switch value {
        case 0x00: return "World 1"
        case 0x01: return "World 2"
        case 0x02: return "World 3"
        case 0x03: return "World 4"
        case 0x04: return "World 5"
        case 0x05: return "World 6"
        case 0x06: return "World 7"
        case 0x07: return "World 8"
        case 0x08: return "World 9"
        default: return "World \(value)"
        }
    }

    private func metroidAreaName(_ value: UInt8) -> String {
        switch value {
        case 0x00: return "Main Deck"
        case 0x01: return "Sector 1"
        case 0x02: return "Sector 2"
        case 0x03: return "Sector 3"
        case 0x04: return "Sector 4"
        case 0x05: return "Sector 5"
        case 0x06: return "Sector 6"
        case 0x07: return "Restricted Lab"
        default: return "Area \(value)"
        }
    }

    private func ariaModeName(_ value: UInt8) -> String {
        switch value {
        case 0x04: return "Game"
        case 0x05: return "Death"
        case 0x06: return "Pause"
        case 0x08: return "Cutscene"
        default: return "Mode \(hex8(UInt16(value)))"
        }
    }

    private func castlevaniaAriaMovementName(_ value: UInt8) -> String {
        switch value {
        case 0x00: return "Move"
        case 0x01: return "Attack"
        case 0x02: return "Subweapon"
        case 0x03: return "Slide"
        case 0x04: return "Recovery"
        case 0x05: return "High Jump"
        case 0x07: return "Dive Kick"
        case 0x08: return "Bat"
        case 0x0C: return "Hurt Ground"
        case 0x0D: return "Hurt Air"
        case 0x0E: return "Launched"
        case 0x10: return "Dead"
        default: return "Move \(hex8(UInt16(value)))"
        }
    }

    private func circleStateName(_ value: UInt8?) -> String {
        guard let value else { return "state --" }
        return "state \(hex8(UInt16(value)))"
    }

    private func hex8(_ value: UInt16) -> String {
        String(format: "%02X", Int(value & 0xFF))
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
    let locationSummary: String?
    let pattern: MarioMemoryPattern?
}
