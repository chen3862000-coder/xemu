// GamePlayView.swift
// Full-screen emulator view for game playback

import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(AppKit)
import AppKit
#endif

struct GamePlayView: View {
    private enum HapticStyle {
        case light
        case medium
    }

    private static let fastForwardSpeeds = [1, 2, 3, 6]

    let game: Game
    let onExit: () -> Void
    
    @EnvironmentObject private var shellThemeManager: ShellThemeManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.emulatorShellTheme) private var shellTheme
    @StateObject private var viewModel = GamePlayViewModel()
    @State private var showPauseMenu = false
    @State private var showSaveSlotsPanel = false
    @State private var showLaunchStatePicker = false
    @State private var pauseSheetMode: PauseSheetMode = .quick
    @State private var fastForwardSpeed: Int = 1
    @State private var startTask: Task<Void, Never>?
    @State private var showCartridgeIntro = false
    @State private var cartridgeOverlayOpacity: CGFloat = 0
    @State private var cartridgeInsertionProgress: CGFloat = 0
    @State private var cartridgeRevealProgress: CGFloat = 0
    @State private var showCartridgePowerOnGlow = false
    @State private var showRetroBootSequence = false
    @State private var retroBootProgress: CGFloat = 0
    @State private var pendingLaunchResumeFlow = false
    @State private var achievementToast: PlayerAchievementUnlock?
    @State private var achievementToastTask: Task<Void, Never>?
    @State private var saveSlotSummaries: [SaveStateSlotSummary] = []
    @AppStorage("resumeLaunchPolicy") private var resumeLaunchPolicyRaw = ResumeLaunchPolicy.autoResumeLatest.rawValue
    @AppStorage("showFPSMeter") private var showFPSMeter = false
    @AppStorage("showCartridgeLaunchIntro") private var showCartridgeLaunchIntro = true
    @AppStorage("settings.dev.memoryMonitor") private var devMemoryMonitor = false
    @AppStorage("settings.dev.thermalLogging") private var devThermalLogging = false
    @AppStorage("settings.dev.gameplayEventOverlay") private var showGameplayEventOverlay = false
    @State private var gameSoundEnabled = true
    @StateObject private var performanceProfiler = PerformanceProfiler.shared
    #if DEBUG
    @AppStorage("showPerformanceHUD") private var showPerformanceHUD = false
    #endif
    
    init(game: Game, onExit: @escaping () -> Void) {
        self.game = game
        self.onExit = onExit
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if !hasUsableGeometry(geometry) {
                    Color.black
                } else if game.gamePlatform == .NDS {
                    ndsConsoleLayout(in: geometry)
                        .environment(\.emulatorShellTheme, resolvedShellTheme)
                } else if game.gamePlatform == .GB || game.gamePlatform == .GBC {
                    gbConsoleLayout(in: geometry)
                        .environment(\.emulatorShellTheme, resolvedShellTheme)
                } else if game.gamePlatform == .GBA {
                    gbaConsoleLayout(in: geometry)
                        .environment(\.emulatorShellTheme, resolvedShellTheme)
                } else {
                    standardGameLayout(in: geometry)
                }

                if showCartridgeIntro {
                    cartridgeLaunchOverlay(in: geometry)
                        .transition(.opacity)
                }
                
                // Pause menu overlay
                if showPauseMenu {
                    pauseMenuOverlay
                }

                if showLaunchStatePicker {
                    launchStatePickerOverlay
                }

                if !viewModel.isRunning,
                   !viewModel.statusMessage.isEmpty,
                   !showPauseMenu,
                   !showLaunchStatePicker {
                    launchFailureOverlay
                }

                if showFPSMeter && viewModel.isRunning {
                    fpsOverlayChip
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                if viewModel.isRunning && (devMemoryMonitor || devThermalLogging) {
                    DeveloperDiagnosticsOverlay(
                        snapshot: performanceProfiler.hudSnapshot,
                        showMemoryMonitor: devMemoryMonitor,
                        showThermalStatus: devThermalLogging
                    )
                    .padding(.top, developerDiagnosticsTopPadding)
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                if viewModel.isRunning,
                   showGameplayEventOverlay,
                   let gameplayAnalysisSnapshot = viewModel.gameplayAnalysisSnapshot {
                    GameplayEventDiagnosticsOverlay(snapshot: gameplayAnalysisSnapshot)
                        .padding(.top, developerDiagnosticsTopPadding + 76)
                        .padding(.leading, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                if let achievementToast {
                    achievementToastOverlay(achievementToast)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .zIndex(20)
                }

                #if DEBUG
                if showPerformanceHUD {
                    performanceHUDOverlay
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                #endif
            }
        }
        .onAppear {
            beginLaunchSequence(allowResumeFlow: true)
        }
        .onDisappear {
            startTask?.cancel()
            startTask = nil
            achievementToastTask?.cancel()
            achievementToastTask = nil
            showCartridgeIntro = false
            cartridgeOverlayOpacity = 0
            cartridgeInsertionProgress = 0
            cartridgeRevealProgress = 0
            showCartridgePowerOnGlow = false
            showRetroBootSequence = false
            retroBootProgress = 0
            pendingLaunchResumeFlow = false
            viewModel.stopEmulation()
        }
        .onChange(of: viewModel.latestUnlockedAchievement?.id) { _, _ in
            guard let unlocked = viewModel.latestUnlockedAchievement else { return }
            achievementToastTask?.cancel()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                achievementToast = unlocked
            }
            triggerHaptic(.light)
            achievementToastTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.26)) {
                    achievementToast = nil
                }
            }
        }
        .onChange(of: showPauseMenu) { _, isPresented in
            if isPresented {
                pauseSheetMode = .quick
                viewModel.pauseEmulation()
                viewModel.refreshSaveStatesStatus()
                saveSlotSummaries = viewModel.saveSlotSummaries()
            } else {
                showSaveSlotsPanel = false
                pauseSheetMode = .quick
            }
        }
    }

    private func achievementToastOverlay(_ unlocked: PlayerAchievementUnlock) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.yellow.opacity(0.18)))

            VStack(alignment: .leading, spacing: 1) {
                Text("Achievement Unlocked")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.78))
                Text(unlocked.title)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.95))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
    }

    private var resumeLaunchPolicy: ResumeLaunchPolicy {
        ResumeLaunchPolicy(rawValue: resumeLaunchPolicyRaw) ?? .autoResumeLatest
    }

    private var developerDiagnosticsTopPadding: CGFloat {
        #if DEBUG
        showPerformanceHUD ? 84 : 12
        #else
        12
        #endif
    }

    private var heavyUIEffectsEnabled: Bool {
        performanceProfiler.currentQualityProfile.heavyUIEffects
    }

    private func beginLaunchSequence(allowResumeFlow: Bool) {
        startTask?.cancel()
        startTask = Task { @MainActor in
            pendingLaunchResumeFlow = false
            if showCartridgeLaunchIntro {
                showCartridgeIntro = true
                cartridgeOverlayOpacity = 1
                showCartridgePowerOnGlow = false
                showRetroBootSequence = false
                cartridgeInsertionProgress = 0
                cartridgeRevealProgress = 0
                retroBootProgress = 0
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.timingCurve(0.18, 0.82, 0.22, 1.0, duration: 0.82)) {
                    cartridgeInsertionProgress = 0.84
                }
                try? await Task.sleep(nanoseconds: 740_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0.12)) {
                    cartridgeInsertionProgress = 1.03
                }

                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }

                playCartridgeInsertionFeedback()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.90, blendDuration: 0.10)) {
                    cartridgeInsertionProgress = 1.0
                }

                try? await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.easeOut(duration: 0.34)) {
                    showCartridgePowerOnGlow = true
                }
                withAnimation(.easeInOut(duration: 0.42)) {
                    cartridgeRevealProgress = 0.46
                }

                try? await Task.sleep(nanoseconds: 240_000_000)
                guard !Task.isCancelled else { return }

                launchGame(allowResumeFlow: allowResumeFlow, deferResumeFlow: true)

                for _ in 0..<18 {
                    if viewModel.isRunning { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    guard !Task.isCancelled else { return }
                }

                if pendingLaunchResumeFlow {
                    pendingLaunchResumeFlow = false
                    handleLaunchResumeFlowIfNeeded()
                }

                withAnimation(.easeInOut(duration: 0.58)) {
                    cartridgeRevealProgress = 1.0
                }

                try? await Task.sleep(nanoseconds: 560_000_000)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.56)) {
                    showCartridgePowerOnGlow = false
                    cartridgeOverlayOpacity = 0
                }

                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled else { return }

                showRetroBootSequence = false
                showCartridgeIntro = false
                cartridgeRevealProgress = 0
                cartridgeInsertionProgress = 0
                cartridgeOverlayOpacity = 0
            } else {
                showCartridgeIntro = false
                cartridgeOverlayOpacity = 0
                showCartridgePowerOnGlow = false
                showRetroBootSequence = false
                cartridgeInsertionProgress = 0
                cartridgeRevealProgress = 0
                retroBootProgress = 0
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                launchGame(allowResumeFlow: allowResumeFlow)
            }
        }
    }

    private func handleLaunchResumeFlowIfNeeded() {
        guard !saveSlotSummaries.isEmpty else { return }
        switch resumeLaunchPolicy {
        case .autoResumeLatest:
            if let latest = saveSlotSummaries
                .filter({ !$0.isEmpty })
                .sorted(by: { ($0.metadata?.createdAt ?? .distantPast) > ($1.metadata?.createdAt ?? .distantPast) })
                .first {
                viewModel.autoResumeLaunchState(latest)
            }
            showLaunchStatePicker = false
        case .startFresh:
            showLaunchStatePicker = false
        case .askEveryTime:
            showLaunchStatePicker = true
        }
    }

    private func launchGame(allowResumeFlow: Bool, deferResumeFlow: Bool = false) {
        guard let romPath = game.romPath, let platform = game.gamePlatform else { return }
        viewModel.startEmulation(
            romPath: romPath,
            platform: platform,
            gameTitle: game.title,
            romHash: game.romPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        )

        guard viewModel.isRunning else { return }
        if allowResumeFlow {
            saveSlotSummaries = viewModel.saveSlotSummaries().filter { !$0.isEmpty }
            guard !saveSlotSummaries.isEmpty else {
                showLaunchStatePicker = false
                pendingLaunchResumeFlow = false
                return
            }
            if deferResumeFlow {
                pendingLaunchResumeFlow = true
                showLaunchStatePicker = false
            } else {
                pendingLaunchResumeFlow = false
                handleLaunchResumeFlowIfNeeded()
            }
        } else {
            pendingLaunchResumeFlow = false
            showLaunchStatePicker = false
        }
    }

    private func restartGameFromPause() {
        triggerHaptic(.medium)
        showLaunchStatePicker = false
        showPauseMenu = false
        showSaveSlotsPanel = false
        pauseSheetMode = .quick
        viewModel.restartEmulation()
    }

    private var resolvedShellTheme: EmulatorShellTheme {
        shellThemeManager.theme(for: game.gamePlatform)
    }

    private var isGBCMinimalShellTheme: Bool {
        game.gamePlatform == .GBC && shellTheme.id == "gbc-modern-minimal"
    }
    private var isGBAMinimalShellTheme: Bool {
        game.gamePlatform == .GBA && shellTheme.id == "gba-modern-minimal"
    }
    private var isNDSMinimalShellTheme: Bool {
        game.gamePlatform == .NDS && shellTheme.id == "nds-modern-minimal"
    }
    private var usesMinimalUtilityChrome: Bool {
        shellTheme.controlStyle.materialType == .glass && !shellTheme.controlStyle.glowEnabled
    }

    private func safeFrameValue(_ value: CGFloat, fallback: CGFloat = 1) -> CGFloat {
        guard value.isFinite, value > 0 else { return fallback }
        return value
    }

    private func safeThemeDimension(_ value: Double, fallback: CGFloat = 32, min: CGFloat = 20, max: CGFloat = 80) -> CGFloat {
        let cg = CGFloat(value)
        guard cg.isFinite, cg > 0 else { return fallback }
        return Swift.min(max, Swift.max(min, cg))
    }

    private func hasUsableGeometry(_ geometry: GeometryProxy) -> Bool {
        let width = geometry.size.width
        let height = geometry.size.height
        guard width.isFinite, height.isFinite else { return false }
        return width > 80 && height > 80
    }

    private func gbConsoleLayout(in geometry: GeometryProxy) -> AnyView {
        if isGBCMinimalShellTheme {
            if isLandscape(geometry) {
                return AnyView(gbcMinimalConsoleLayoutLandscape(in: geometry))
            } else {
                return AnyView(gbcMinimalConsoleLayoutPortrait(in: geometry))
            }
        } else if isLandscape(geometry) {
            return AnyView(gbConsoleLayoutLandscape(in: geometry))
        } else {
            let isGBC = game.gamePlatform == .GBC
            let gbScreenScale = (game.gamePlatform == .GBC) ? 0.70 : 0.77
            let gbControlScale: CGFloat = (game.gamePlatform == .GBC) ? 0.88 : 0.92
            let shellWidth = safeFrameValue(max(220, min(geometry.size.width - 18, 430.0)), fallback: 220)
            let shellHeight = safeFrameValue(max(360, min(geometry.size.height - 20, 900.0)), fallback: 360)
            let displayFrameWidth = safeFrameValue(shellWidth - 28, fallback: 180)
            let displayFrameHeight = safeFrameValue(min(shellHeight * 0.48, 470), fallback: 180)
            let gameWidth = safeFrameValue(min(displayFrameWidth - 8, displayFrameWidth * gbScreenScale), fallback: 120)
            let gameHeight = safeFrameValue(gameWidth * (144.0 / 160.0), fallback: 108)

            return AnyView(
            VStack(spacing: 0) {
                HStack {
                    Text(game.title ?? "Game Boy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)
                    Spacer()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isGBC
                                    ? [
                                        Color(red: 0.99, green: 0.31, blue: 0.85).opacity(0.20),
                                        Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.24),
                                        Color(red: 0.43, green: 0.91, blue: 0.98).opacity(0.14)
                                    ]
                                    : [
                                        Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.14),
                                        Color(red: 0.12, green: 0.10, blue: 0.22).opacity(0.22)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(Color.white.opacity(isGBC ? 0.10 : 0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.22), Color.purple.opacity(0.28), Color.pink.opacity(0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.purple.opacity(0.22), radius: 30, x: 0, y: 12)
                        .shadow(color: Color.pink.opacity(0.16), radius: 20, x: 0, y: 8)

                    VStack(spacing: 0) {
                        Spacer().frame(height: 14)

                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(red: 0.07, green: 0.09, blue: 0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        .padding(2)
                                )
                                .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 6)

                            VStack(spacing: 0) {
                                ZStack(alignment: .top) {
                                    emulatorDisplayView
                                        .frame(width: gameWidth, height: gameHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )

                                }
                                .padding(.top, 10)

                                Spacer(minLength: 0)

                                HStack(spacing: 10) {
                                    gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green) { viewModel.quickSave() }
                                    gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange) { viewModel.quickLoad() }
                                    Spacer()
                                    gbUtilityIcon(systemName: "forward.fill", tint: .yellow) {
                                        cycleFastForwardSpeed()
                                    }
                                    ZStack {
                                        gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {
                                            toggleGameSound()
                                        }
                                        if !gameSoundEnabled {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 20, weight: .light))
                                                .foregroundColor(.red)
                                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                            }
                        }
                        .frame(width: displayFrameWidth, height: displayFrameHeight)

                        Spacer(minLength: 0)

                        HStack(alignment: .center) {
                            GBDPadView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbControlScale)
                            Spacer()
                            GBFaceButtonsView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbControlScale)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 230 * gbControlScale + 14)
                        .offset(y: -28)

                        shellSystemButtonsRow(theme: .neoGlass) {
                            showPauseMenu = true
                        } onSelectPress: { pressed in
                            viewModel.handleButtonPress(.select, pressed: pressed)
                        } onStartPress: { pressed in
                            viewModel.handleButtonPress(.start, pressed: pressed)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                        .offset(y: -22)
                        .scaleEffect(gbControlScale)
                    }
                }
                .frame(width: shellWidth, height: shellHeight)
                .padding(.bottom, 6)

                statusBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            )
        }
    }

    private func gbcMinimalConsoleLayoutPortrait(in geometry: GeometryProxy) -> AnyView {
        let shellWidth = safeFrameValue(max(220, min(geometry.size.width - 20, 430.0)), fallback: 220)
        let shellHeight = safeFrameValue(max(360, min(geometry.size.height - 20, 900.0)), fallback: 360)
        let displayFrameWidth = safeFrameValue(shellWidth - 28, fallback: 180)
        let displayFrameHeight = safeFrameValue(min(shellHeight * 0.44, 410), fallback: 170)
        let gameWidth = safeFrameValue(min(displayFrameWidth - 26, displayFrameWidth * 0.70), fallback: 120)
        let gameHeight = safeFrameValue(gameWidth * (144.0 / 160.0), fallback: 108)
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.90)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.90)

        return AnyView(
        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Color")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer()
                if pauseSheetMode == .quick, !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [shellPalette.shellBaseTop.color, shellPalette.shellBaseBottom.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(shellPalette.shellStroke.color.opacity(0.9), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.05), Color.clear, Color.black.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: shellPalette.shellShadow.color.opacity(0.9), radius: 18, x: 0, y: 10)

                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)

                        emulatorDisplayView
                            .frame(width: gameWidth, height: gameHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .frame(width: displayFrameWidth, height: displayFrameHeight)

                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            gbUtilityIcon(systemName: "square.and.arrow.down", tint: .white) { viewModel.quickSave() }
                            gbUtilityIcon(systemName: "square.and.arrow.up", tint: .white) { viewModel.quickLoad() }
                            gbUtilityIcon(systemName: "forward.fill", tint: .white) {
                                cycleFastForwardSpeed()
                            }
                            ZStack {
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {
                                    toggleGameSound()
                                }
                                if !gameSoundEnabled {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        Spacer(minLength: 0)
                    }
                    .frame(height: 44)

                    HStack(alignment: .center) {
                        GBDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(dpadScale)
                        .opacity(shellTheme.controlStyle.idleOpacity)

                        Spacer(minLength: 18)

                        GBFaceButtonsView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(faceScale)
                        .opacity(shellTheme.controlStyle.idleOpacity)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 210)
                    .offset(y: -4)

                    shellSystemButtonsRow(theme: .neoGlass) {
                        showPauseMenu = true
                    } onSelectPress: { pressed in
                        viewModel.handleButtonPress(.select, pressed: pressed)
                    } onStartPress: { pressed in
                        viewModel.handleButtonPress(.start, pressed: pressed)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                    .offset(y: -4)
                }
                .padding(.top, 12)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)

            statusBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
    }

    private func gbcMinimalConsoleLayoutLandscape(in geometry: GeometryProxy) -> AnyView {
        guard hasUsableGeometry(geometry) else { return AnyView(Color.black) }
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let shellWidth = safeFrameValue(max(520, min(geometry.size.width - safeLeading - safeTrailing - 18, 920.0)), fallback: 520)
        let shellHeight = safeFrameValue(max(260, min(geometry.size.height - 18, 430.0)), fallback: 260)
        let innerWidth = safeFrameValue(shellWidth - 28, fallback: 492)
        let columnGap: CGFloat = 14
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.82)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.82)
        let dpadSize = 182 * dpadScale
        let faceSize = 190 * faceScale
        let sideColumnWidth = safeFrameValue(max(190, min(220, (innerWidth - 360 - columnGap * 2) / 2)), fallback: 190)
        let centerWidth = safeFrameValue(max(340, innerWidth - sideColumnWidth * 2 - columnGap * 2), fallback: 340)
        let screenWidth = safeFrameValue(min(centerWidth - 28, centerWidth * 0.74), fallback: 180)
        let screenHeight = safeFrameValue(min(screenWidth * (144.0 / 160.0), shellHeight * 0.58), fallback: 120)
        let centerCardHeight = safeFrameValue(min(shellHeight * 0.70, 286), fallback: 220)

        return AnyView(
        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Color")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [shellPalette.shellBaseTop.color, shellPalette.shellBaseBottom.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(RoundedRectangle(cornerRadius: 28).fill(Color.white.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(shellPalette.shellStroke.color.opacity(0.9), lineWidth: 1))
                    .shadow(color: shellPalette.shellShadow.color.opacity(0.9), radius: 18, x: 0, y: 10)

                HStack(spacing: columnGap) {
                    VStack(spacing: 10) {
                        Spacer(minLength: 0)
                        GBDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(dpadScale)
                        .frame(width: dpadSize, height: dpadSize)
                        .opacity(shellTheme.controlStyle.idleOpacity)
                        Spacer(minLength: 0)
                        shellLandscapeMenuButton(theme: .neoGlass) {
                            showPauseMenu = true
                        }
                    }
                    .frame(width: sideColumnWidth, height: centerCardHeight + 44)

                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)

                            emulatorDisplayView
                                .frame(width: screenWidth, height: screenHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        }
                        .frame(width: centerWidth, height: centerCardHeight)

                        HStack(spacing: 8) {
                            gbUtilityIcon(systemName: "square.and.arrow.down", tint: .white) { viewModel.quickSave() }
                            gbUtilityIcon(systemName: "square.and.arrow.up", tint: .white) { viewModel.quickLoad() }
                            Spacer()
                            gbUtilityIcon(systemName: "forward.fill", tint: .white) {
                                cycleFastForwardSpeed()
                            }
                            ZStack {
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {
                                    toggleGameSound()
                                }
                                if !gameSoundEnabled {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .frame(width: centerWidth)

                    VStack(spacing: 10) {
                        Spacer(minLength: 0)
                        GBFaceButtonsView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(faceScale)
                        .frame(width: faceSize, height: faceSize)
                        .opacity(shellTheme.controlStyle.idleOpacity)
                        Spacer(minLength: 0)
                        shellLandscapeSelectStartRow(theme: .neoGlass) { pressed in
                            viewModel.handleButtonPress(.select, pressed: pressed)
                        } onStartPress: { pressed in
                            viewModel.handleButtonPress(.start, pressed: pressed)
                        }
                    }
                    .frame(width: sideColumnWidth, height: centerCardHeight + 44)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)

            statusBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
        .padding(.leading, safeLeading)
        .padding(.trailing, safeTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
    }

    private func standardGameLayout(in geometry: GeometryProxy) -> AnyView {
        guard hasUsableGeometry(geometry) else { return AnyView(Color.black) }
        if isLandscape(geometry) {
            return AnyView(
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(game.title ?? "Unknown Game")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showPauseMenu = true }) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))

                    emulatorDisplayView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    statusBar
                }
                .frame(width: geometry.size.width * 0.58)
                .clipped()

                VirtualPadView(
                    platform: game.gamePlatform ?? .GB,
                    onButtonPress: { button, isPressed in
                        viewModel.handleButtonPress(button, pressed: isPressed)
                    }
                )
                .scaleEffect(0.86)
                .offset(y: -10)
                .frame(width: geometry.size.width * 0.42)
                .clipped()
            }
            )
        } else {
            return AnyView(
            VStack(spacing: 0) {
                // Top half: Game display
                VStack(spacing: 0) {
                    // Game title bar
                    HStack {
                        Text(game.title ?? "Unknown Game")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showPauseMenu = true }) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    
                    emulatorDisplayView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    statusBar
                }
                .frame(height: geometry.size.height * 0.5)
                .clipped()
                
                VirtualPadView(
                    platform: game.gamePlatform ?? .GB,
                    onButtonPress: { button, isPressed in
                        viewModel.handleButtonPress(button, pressed: isPressed)
                    }
                )
                .offset(y: -18)
                .frame(height: geometry.size.height * 0.5)
                .clipped()
            }
            )
        }
    }

    private func gbaConsoleLayout(in geometry: GeometryProxy) -> some View {
        if isGBAMinimalShellTheme {
            if isLandscape(geometry) {
                return AnyView(gbaMinimalConsoleLayoutLandscape(in: geometry))
            } else {
                return AnyView(gbaMinimalConsoleLayoutPortrait(in: geometry))
            }
        } else if isLandscape(geometry) {
            return AnyView(gbaConsoleLayoutLandscape(in: geometry))
        } else {
            let gbaScreenScale: CGFloat = 0.84
            let gbaControlScale: CGFloat = 0.90
            let shellWidth = safeFrameValue(max(220, min(geometry.size.width - 18, 430.0)), fallback: 220)
            let shellHeight = safeFrameValue(max(360, min(geometry.size.height - 18, 900.0)), fallback: 360)
            let displayOuterWidth = safeFrameValue(shellWidth, fallback: 220)
            let displayOuterHeight = safeFrameValue(max(180, min(shellHeight * 0.53, 500)), fallback: 180)
            let screenWidth = safeFrameValue(min(displayOuterWidth - 16, displayOuterWidth * gbaScreenScale), fallback: 120)
            let screenHeight = safeFrameValue(screenWidth * (160.0 / 240.0), fallback: 80)

            return AnyView(
            VStack(spacing: 0) {
                HStack {
                    Text(game.title ?? "Game Boy Advance")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(1)
                    Spacer()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.26, green: 0.12, blue: 0.58),
                                    Color(red: 0.12, green: 0.04, blue: 0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.05), Color.clear, Color.black.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Color.purple.opacity(0.35), radius: 28, x: 0, y: 12)

                    VStack(spacing: 0) {
                        Spacer().frame(height: 10)

                        VStack(spacing: 0) {
                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(Color.black.opacity(0.95))

                                emulatorDisplayView
                                    .frame(width: screenWidth, height: screenHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .padding(.top, 36)

                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: safeFrameValue(screenWidth - 10, fallback: 1), height: 1)
                                    .padding(.top, 22)
                            }
                            .frame(width: displayOuterWidth, height: displayOuterHeight)

                            HStack(spacing: 14) {
                                gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green) { viewModel.quickSave() }
                                gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange) { viewModel.quickLoad() }
                                Spacer()
                                gbUtilityIcon(systemName: "forward.fill", tint: .yellow) {
                                    cycleFastForwardSpeed()
                                }
                                ZStack {
                                    gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {
                                        toggleGameSound()
                                    }
                                    if !gameSoundEnabled {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 18, weight: .light))
                                            .foregroundColor(.red)
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(width: displayOuterWidth, height: 54)
                            .background(Color.black.opacity(0.98))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )

                        HStack {
                            GBAShoulderBar(label: "L") {
                                viewModel.handleButtonPress(.l1, pressed: true)
                            } onRelease: {
                                viewModel.handleButtonPress(.l1, pressed: false)
                            }
                            Spacer()
                            GBAShoulderBar(label: "R") {
                                viewModel.handleButtonPress(.r1, pressed: true)
                            } onRelease: {
                                viewModel.handleButtonPress(.r1, pressed: false)
                            }
                        }
                        .padding(.horizontal, 4)
                        .offset(y: -4)

                        Spacer(minLength: 8)

                        HStack(alignment: .center) {
                            GBALightDPadView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbaControlScale)
                            Spacer()
                            GBAFaceButtonsView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbaControlScale)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 230 * gbaControlScale + 14)
                        .offset(y: -34)

                        shellSystemButtonsRow(theme: .darkPurple) {
                            showPauseMenu = true
                        } onSelectPress: { pressed in
                            viewModel.handleButtonPress(.select, pressed: pressed)
                        } onStartPress: { pressed in
                            viewModel.handleButtonPress(.start, pressed: pressed)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .offset(y: -28)
                        .scaleEffect(gbaControlScale)
                    }
                }
                .frame(width: shellWidth, height: shellHeight)
                .padding(.bottom, 6)

                statusBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            )
        }
    }

    private func gbaMinimalConsoleLayoutPortrait(in geometry: GeometryProxy) -> some View {
        let shellWidth = safeFrameValue(max(220, min(geometry.size.width - 18, 430.0)), fallback: 220)
        let shellHeight = safeFrameValue(max(360, min(geometry.size.height - 18, 900.0)), fallback: 360)
        let screenWidth = safeFrameValue(min(shellWidth - 30, 380.0), fallback: 120)
        let screenHeight = safeFrameValue(screenWidth * (160.0 / 240.0), fallback: 80)
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.82)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.82)

        return VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Advance")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer()
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [shellPalette.shellBaseTop.color, shellPalette.shellBaseBottom.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(RoundedRectangle(cornerRadius: 28).fill(Color.white.opacity(0.02)))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(shellPalette.shellStroke.color.opacity(0.9), lineWidth: 1))
                    .shadow(color: shellPalette.shellShadow.color.opacity(0.9), radius: 18, x: 0, y: 10)

                VStack(spacing: 16) {
                    HStack {
                        GBAShoulderBar(label: "L") {
                            viewModel.handleButtonPress(.l1, pressed: true)
                        } onRelease: { viewModel.handleButtonPress(.l1, pressed: false) }
                        Spacer()
                        GBAShoulderBar(label: "R") {
                            viewModel.handleButtonPress(.r1, pressed: true)
                        } onRelease: { viewModel.handleButtonPress(.r1, pressed: false) }
                    }
                    .padding(.horizontal, 6)

                    HStack(spacing: 8) {
                        gbUtilityIcon(systemName: "square.and.arrow.down", tint: .white) { viewModel.quickSave() }
                        gbUtilityIcon(systemName: "square.and.arrow.up", tint: .white) { viewModel.quickLoad() }
                        gbUtilityIcon(systemName: "forward.fill", tint: .white) {
                            cycleFastForwardSpeed()
                        }
                        ZStack {
                            gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {
                                toggleGameSound()
                            }
                            if !gameSoundEnabled {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(.red)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.24), radius: 20, x: 0, y: 10)

                        emulatorDisplayView
                            .frame(width: screenWidth, height: screenHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .frame(width: screenWidth + 18, height: screenHeight + 18)

                    HStack(alignment: .center, spacing: 20) {
                        GBALightDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(dpadScale)
                        .opacity(shellTheme.controlStyle.idleOpacity)

                        GBAFaceButtonsView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(faceScale)
                        .opacity(shellTheme.controlStyle.idleOpacity)
                    }
                    .padding(.horizontal, 12)
                    .offset(y: -4)

                    shellSystemButtonsRow(theme: .neoGlass) {
                        showPauseMenu = true
                    } onSelectPress: { pressed in
                        viewModel.handleButtonPress(.select, pressed: pressed)
                    } onStartPress: { pressed in
                        viewModel.handleButtonPress(.start, pressed: pressed)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 2)
                    .offset(y: -6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)

            statusBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func gbaMinimalConsoleLayoutLandscape(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let shellWidth = safeFrameValue(max(520, min(geometry.size.width - safeLeading - safeTrailing - 14, 1180.0)), fallback: 520)
        let shellHeight = safeFrameValue(max(260, min(geometry.size.height - 14, 520.0)), fallback: 260)
        let innerWidth = safeFrameValue(shellWidth - 24, fallback: 496)
        let sideWidth: CGFloat = 136
        let gap: CGFloat = 12
        let centerWidth = safeFrameValue(max(360, min(880, innerWidth - (sideWidth * 2) - (gap * 2))), fallback: 360)
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.78)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.78)
        let screenWidth = safeFrameValue(min(centerWidth - 30, centerWidth * 0.90), fallback: 180)
        let screenHeight = safeFrameValue(min(screenWidth * (160.0 / 240.0), shellHeight * 0.52), fallback: 120)

        return VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Advance")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [shellPalette.shellBaseTop.color, shellPalette.shellBaseBottom.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(RoundedRectangle(cornerRadius: 26).fill(Color.white.opacity(0.02)))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(shellPalette.shellStroke.color.opacity(0.9), lineWidth: 1))
                    .shadow(color: shellPalette.shellShadow.color.opacity(0.9), radius: 18, x: 0, y: 10)

                VStack(spacing: 10) {
                    HStack {
                        GBAShoulderBar(label: "L") {
                            viewModel.handleButtonPress(.l1, pressed: true)
                        } onRelease: { viewModel.handleButtonPress(.l1, pressed: false) }
                        Spacer()
                        GBAShoulderBar(label: "R") {
                            viewModel.handleButtonPress(.r1, pressed: true)
                        } onRelease: { viewModel.handleButtonPress(.r1, pressed: false) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    HStack(spacing: gap) {
                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            GBALightDPadView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(dpadScale)
                            .opacity(shellTheme.controlStyle.idleOpacity)
                            Spacer(minLength: 0)
                            shellLandscapeMenuButton(theme: .neoGlass) {
                                showPauseMenu = true
                            }
                        }
                        .frame(width: sideWidth, height: screenHeight + 94)

                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                gbUtilityIcon(systemName: "square.and.arrow.down", tint: .white) { viewModel.quickSave() }
                                gbUtilityIcon(systemName: "square.and.arrow.up", tint: .white) { viewModel.quickLoad() }
                                gbUtilityIcon(systemName: "forward.fill", tint: .white) {
                                    cycleFastForwardSpeed()
                                }
                                ZStack {
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {
                                    toggleGameSound()
                                }
                                if !gameSoundEnabled {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                            }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))

                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.black)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)

                                emulatorDisplayView
                                    .frame(width: screenWidth, height: screenHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            }
                            .frame(width: centerWidth, height: screenHeight + 24)
                        }
                        .frame(width: centerWidth)

                        VStack(spacing: 12) {
                            Spacer(minLength: 0)
                            GBAFaceButtonsView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(faceScale)
                            .opacity(shellTheme.controlStyle.idleOpacity)
                            Spacer(minLength: 0)
                            shellLandscapeSelectStartRow(theme: .neoGlass) { pressed in
                                viewModel.handleButtonPress(.select, pressed: pressed)
                            } onStartPress: { pressed in
                                viewModel.handleButtonPress(.start, pressed: pressed)
                            }
                        }
                        .frame(width: sideWidth, height: screenHeight + 94)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)

            statusBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
        .padding(.leading, safeLeading)
        .padding(.trailing, safeTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func ndsConsoleLayout(in geometry: GeometryProxy) -> AnyView {
        guard hasUsableGeometry(geometry) else { return AnyView(Color.black) }
        if isNDSMinimalShellTheme {
            if isLandscape(geometry) {
                return AnyView(
                    ndsMinimalConsoleLayoutLandscape(in: geometry)
                    .onAppear { viewModel.setNDSScreenLayout(.sideBySide) }
                )
            } else {
                return AnyView(
                    ndsMinimalConsoleLayoutPortrait(in: geometry)
                    .onAppear { viewModel.setNDSScreenLayout(.stacked) }
                )
            }
        }
        if isLandscape(geometry) {
            return AnyView(
                ndsConsoleLayoutLandscapeShell(in: geometry)
                .onAppear {
                    viewModel.setNDSScreenLayout(.sideBySide)
                }
            )
        } else {
            let shellWidth = safeFrameValue(min(geometry.size.width - 18, 420.0), fallback: 220)
            let shellHeight = safeFrameValue(min(geometry.size.height - 28, 860.0), fallback: 360)
            // Keep core controls reachable above the home indicator.
            let controllerBottomMargin = max(8.0, min(16.0, geometry.safeAreaInsets.bottom + 2.0))

            return AnyView(
                VStack(spacing: 0) {
                    ndsTopBar
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    ndsConsoleLayoutPortraitShell(
                        width: shellWidth,
                        height: shellHeight,
                        viewportWidth: geometry.size.width,
                        controllerBottomMargin: controllerBottomMargin
                    )
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onAppear {
                    viewModel.setNDSScreenLayout(.stacked)
                }
            )
        }
    }

    private func ndsMinimalConsoleLayoutPortrait(in geometry: GeometryProxy) -> some View {
        let shellWidth = min(geometry.size.width - 18, 430.0)
        let shellHeight = min(geometry.size.height - 18, 900.0)
        let screenAreaWidth = shellWidth - 26
        let topCardWidth = min(screenAreaWidth, 360)
        let topCardHeight = topCardWidth * (192.0 / 256.0)
        let bottomCardWidth = min(screenAreaWidth + 4, 372)
        let bottomCardHeight = bottomCardWidth * (192.0 / 256.0)
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.78)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.78)
        let touchGlow = shellPalette.ndsTouchHighlight.color.opacity(shellOverride.touchScreenHighlightOpacity ?? 0.22)

        return VStack(spacing: 0) {
            ndsTopBar
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [shellPalette.shellBaseTop.color, shellPalette.shellBaseBottom.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(RoundedRectangle(cornerRadius: 28).fill(Color.white.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(shellPalette.shellStroke.color.opacity(0.9), lineWidth: 1))
                    .shadow(color: shellPalette.shellShadow.color.opacity(0.9), radius: 20, x: 0, y: 10)

                VStack(spacing: 14) {
                    HStack {
                        GBAShoulderBar(label: "L") {
                            viewModel.handleButtonPress(.l1, pressed: true)
                        } onRelease: {
                            viewModel.handleButtonPress(.l1, pressed: false)
                        }
                        Spacer()
                        GBAShoulderBar(label: "R") {
                            viewModel.handleButtonPress(.r1, pressed: true)
                        } onRelease: {
                            viewModel.handleButtonPress(.r1, pressed: false)
                        }
                    }
                    .padding(.horizontal, 6)

                    VStack(spacing: 20) {
                        ndsMinimalScreenCard(
                            width: topCardWidth,
                            height: topCardHeight,
                            cornerRadius: 20,
                            shadowRadius: 16,
                            shadowY: 7,
                            highlight: .clear
                        ) {
                            emulatorDisplayView
                                .frame(width: topCardWidth, height: topCardHeight * 2 + 20)
                                .offset(y: topCardHeight / 2 + 10)
                        }

                        ndsMinimalScreenCard(
                            width: bottomCardWidth,
                            height: bottomCardHeight,
                            cornerRadius: 20,
                            shadowRadius: 18,
                            shadowY: 8,
                            highlight: touchGlow
                        ) {
                            ZStack {
                                emulatorDisplayView
                                    .frame(width: bottomCardWidth, height: bottomCardHeight * 2 + 20)
                                    .offset(y: -(bottomCardHeight / 2 + 10))

                                NDSTouchScreenOverlayView(
                                    onStylus: { normalizedX, normalizedY, pressed in
                                    if pressed {
                                        viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                                    } else {
                                        viewModel.clearNDSTouch()
                                    }
                                },
                                    yBiasNormalized: 20.0 / ((bottomCardHeight * 2.0) + 20.0)
                                )
                                .frame(width: bottomCardWidth, height: bottomCardHeight)
                            }
                        }
                    }

                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            gbUtilityIcon(systemName: "square.and.arrow.down", tint: .white) { viewModel.quickSave() }
                            gbUtilityIcon(systemName: "square.and.arrow.up", tint: .white) { viewModel.quickLoad() }
                            gbUtilityIcon(systemName: "forward.fill", tint: .white) {
                                cycleFastForwardSpeed()
                            }
                            ZStack {
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {
                                    toggleGameSound()
                                }
                                if !gameSoundEnabled {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .center, spacing: 18) {
                        NDSDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(dpadScale)
                        .opacity(shellTheme.controlStyle.idleOpacity)

                        NDSFaceClusterView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(faceScale)
                        .opacity(shellTheme.controlStyle.idleOpacity)
                    }
                    .padding(.horizontal, 14)
                    .offset(y: -4)

                    ndsQuickStateRow
                    .offset(y: -2)

                    shellSystemButtonsRow(theme: .neoGlass) {
                        showPauseMenu = true
                    } onSelectPress: { pressed in
                        viewModel.handleButtonPress(.select, pressed: pressed)
                    } onStartPress: { pressed in
                        viewModel.handleButtonPress(.start, pressed: pressed)
                    }
                    .scaleEffect(0.85)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func ndsMinimalConsoleLayoutLandscape(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let shellWidth = min(geometry.size.width - safeLeading - safeTrailing - 12, 1180.0)
        let shellHeight = min(geometry.size.height - 12, 620.0)
        let innerWidth = shellWidth - 28
        let sideColumnWidth: CGFloat = 118
        let centerGap: CGFloat = 10
        let centerWidth = max(560, min(920, innerWidth - (sideColumnWidth * 2) - (centerGap * 2)))
        let screenWidth = (centerWidth - 12) / 2
        let screenHeight = screenWidth * (192.0 / 256.0)
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.76)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.76)
        let touchGlow = shellPalette.ndsTouchHighlight.color.opacity(shellOverride.touchScreenHighlightOpacity ?? 0.22)

        return VStack(spacing: 0) {
            ndsTopBar
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [shellPalette.shellBaseTop.color, shellPalette.shellBaseBottom.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(RoundedRectangle(cornerRadius: 26).fill(Color.white.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(shellPalette.shellStroke.color.opacity(0.9), lineWidth: 1))
                    .shadow(color: shellPalette.shellShadow.color.opacity(0.9), radius: 20, x: 0, y: 10)

                VStack(spacing: 8) {
                    HStack {
                        GBAShoulderBar(label: "L") {
                            viewModel.handleButtonPress(.l1, pressed: true)
                        } onRelease: {
                            viewModel.handleButtonPress(.l1, pressed: false)
                        }
                        Spacer()
                        GBAShoulderBar(label: "R") {
                            viewModel.handleButtonPress(.r1, pressed: true)
                        } onRelease: {
                            viewModel.handleButtonPress(.r1, pressed: false)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                    HStack(spacing: centerGap) {
                        VStack(spacing: 10) {
                            Spacer(minLength: 0)
                            NDSDPadView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(dpadScale)
                            .opacity(shellTheme.controlStyle.idleOpacity)
                            Spacer(minLength: 0)
                            shellLandscapeMenuButton(theme: .neoGlass) {
                                showPauseMenu = true
                            }
                        }
                        .frame(width: sideColumnWidth, height: screenHeight + 90)

                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                let upperTransform = ndsLandscapeScreenTransform(
                                    visibleWidth: screenWidth,
                                    visibleHeight: screenHeight,
                                    interScreenSpacing: 12,
                                    isTouchScreen: false
                                )
                                let lowerTransform = ndsLandscapeScreenTransform(
                                    visibleWidth: screenWidth,
                                    visibleHeight: screenHeight,
                                    interScreenSpacing: 12,
                                    isTouchScreen: true
                                )
                                ndsMinimalScreenCard(
                                    width: screenWidth,
                                    height: screenHeight,
                                    cornerRadius: 18,
                                    shadowRadius: 16,
                                    shadowY: 7,
                                    highlight: .clear
                                ) {
                                    emulatorDisplayView
                                        .frame(width: upperTransform.sourceWidth, height: upperTransform.sourceHeight)
                                        .offset(x: upperTransform.xOffset, y: upperTransform.yOffset)
                                }

                                ndsMinimalScreenCard(
                                    width: screenWidth,
                                    height: screenHeight,
                                    cornerRadius: 18,
                                    shadowRadius: 18,
                                    shadowY: 8,
                                    highlight: touchGlow
                                ) {
                                    ZStack {
                                        emulatorDisplayView
                                            .frame(width: lowerTransform.sourceWidth, height: lowerTransform.sourceHeight)
                                            .offset(x: lowerTransform.xOffset, y: lowerTransform.yOffset)

                                        NDSTouchScreenOverlayView { normalizedX, normalizedY, pressed in
                                            if pressed {
                                                viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                                            } else {
                                                viewModel.clearNDSTouch()
                                            }
                                        }
                                        .frame(width: screenWidth, height: screenHeight)
                                    }
                                }
                            }
                            .frame(width: centerWidth)

                            HStack(spacing: 8) {
                                gbUtilityIcon(systemName: "square.and.arrow.down", tint: .white) { viewModel.quickSave() }
                                gbUtilityIcon(systemName: "square.and.arrow.up", tint: .white) { viewModel.quickLoad() }
                                gbUtilityIcon(systemName: "forward.fill", tint: .white) {
                                    cycleFastForwardSpeed()
                                }
                                ZStack {
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {
                                    toggleGameSound()
                                }
                                if !gameSoundEnabled {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.red)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                            }
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 42)
                            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .frame(width: centerWidth)

                        VStack(spacing: 10) {
                            Spacer(minLength: 0)
                            NDSFaceClusterView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(faceScale)
                            .opacity(shellTheme.controlStyle.idleOpacity)
                            Spacer(minLength: 0)
                            shellLandscapeSelectStartRow(theme: .neoGlass) { pressed in
                                viewModel.handleButtonPress(.select, pressed: pressed)
                            } onStartPress: { pressed in
                                viewModel.handleButtonPress(.start, pressed: pressed)
                            }
                        }
                        .frame(width: sideColumnWidth, height: screenHeight + 90)
                    }
                    .padding(.horizontal, 14)

                    ndsQuickStateRow
                    .padding(.bottom, 8)
                }
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)
        }
        .padding(.leading, safeLeading)
        .padding(.trailing, safeTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func ndsMinimalScreenCard<Content: View>(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        shadowRadius: CGFloat,
        shadowY: CGFloat,
        highlight: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.24), radius: shadowRadius, x: 0, y: shadowY)
                .shadow(color: highlight.opacity(0.8), radius: 12, x: 0, y: 2)

            content()
                .clipShape(RoundedRectangle(cornerRadius: max(8, cornerRadius - 8), style: .continuous))
        }
        .frame(width: width, height: height)
    }

    private func ndsConsoleLayoutLandscapeShell(in geometry: GeometryProxy) -> AnyView {
        guard hasUsableGeometry(geometry) else { return AnyView(Color.black) }
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        // Landscape-only layout rules (independent from portrait control rules).
        let cameraSideExclusionInset: CGFloat = 34
        let cameraOnLeadingSide = safeLeading > safeTrailing
        let cameraLeadingInset = cameraOnLeadingSide ? cameraSideExclusionInset : 0
        let cameraTrailingInset = cameraOnLeadingSide ? 0 : cameraSideExclusionInset

        let availableWidth = geometry.size.width - safeLeading - safeTrailing - cameraLeadingInset - cameraTrailingInset
        let shellWidth = safeFrameValue(max(760, min(availableWidth - 2, 1320.0)), fallback: 760)
        let shellHeight = safeFrameValue(max(340, min(geometry.size.height * 0.92, 500.0)), fallback: 340)

        return AnyView(
            ndsLandscapeShellBody(
                shellWidth: shellWidth,
                shellHeight: shellHeight,
                safeLeading: safeLeading,
                safeTrailing: safeTrailing,
                cameraLeadingInset: cameraLeadingInset,
                cameraTrailingInset: cameraTrailingInset
            )
        )
    }

    private func ndsLandscapeShellBody(
        shellWidth: CGFloat,
        shellHeight: CGFloat,
        safeLeading: CGFloat,
        safeTrailing: CGFloat,
        cameraLeadingInset: CGFloat,
        cameraTrailingInset: CGFloat
    ) -> some View {
        let shellHorizontalOffset = ndsLandscapeHorizontalOffset(
            safeLeading: safeLeading,
            safeTrailing: safeTrailing,
            cameraLeadingInset: cameraLeadingInset,
            cameraTrailingInset: cameraTrailingInset
        )
        return VStack(spacing: 0) {
            ndsTopBar
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.97),
                                Color(red: 0.92, green: 0.92, blue: 0.94),
                                Color(red: 0.86, green: 0.86, blue: 0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 42, style: .continuous)
                            .stroke(Color.black.opacity(0.16), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 42, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                            .padding(1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)

                GeometryReader { deckGeo in
                    let metrics = ndsLandscapeMetrics(
                        contentWidth: deckGeo.size.width,
                        contentHeight: deckGeo.size.height
                    )
                    ndsLandscapeDeckLayer(metrics: metrics)
                        .frame(width: deckGeo.size.width, height: deckGeo.size.height)
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 6)
        }
        .padding(.leading, safeLeading + cameraLeadingInset)
        .padding(.trailing, safeTrailing + cameraTrailingInset)
        .offset(x: shellHorizontalOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func ndsLandscapeHorizontalOffset(
        safeLeading: CGFloat,
        safeTrailing: CGFloat,
        cameraLeadingInset: CGFloat,
        cameraTrailingInset: CGFloat
    ) -> CGFloat {
        (((safeLeading + cameraLeadingInset) - (safeTrailing + cameraTrailingInset)) / 2) - 48
    }

    private struct NDSLandscapeLayoutMetrics {
        let contentWidth: CGFloat
        let contentHeight: CGFloat
        let deckWidth: CGFloat
        let deckHeight: CGFloat
        let deckTop: CGFloat
        let shoulderWidth: CGFloat
        let shoulderHeight: CGFloat
        let shoulderY: CGFloat
        let utilityWidth: CGFloat
        let utilityHeight: CGFloat
        let utilityY: CGFloat
        let dpadY: CGFloat
        let abxyY: CGFloat
        let centerY: CGFloat
        let dpadX: CGFloat
        let abxyX: CGFloat
        let dpadSize: CGFloat
        let faceButtonDiameter: CGFloat
        let faceButtonSpacing: CGFloat
        let faceClusterHitSize: CGFloat
    }

    private func ndsLandscapeMetrics(contentWidth: CGFloat, contentHeight: CGFloat) -> NDSLandscapeLayoutMetrics {
        let deckWidth = min(contentWidth * 0.88, 1040)
        let deckHeight = min(contentHeight * 0.64, 384)
        let deckTop: CGFloat = -4
        let shoulderWidth: CGFloat = 34
        let shoulderHeight: CGFloat = 96
        let dpadSize: CGFloat = 126
        let faceButtonDiameter: CGFloat = 50
        let faceButtonSpacing: CGFloat = 10
        let faceClusterHitSize: CGFloat = 66
        let faceClusterHalfWidth = faceButtonSpacing + faceButtonDiameter
        let deckMinX = deckMinX(for: contentWidth, deckWidth: deckWidth)
        let deckMaxX = deckMaxX(for: contentWidth, deckWidth: deckWidth)
        let controlToDeckGap: CGFloat = 24
        let shellSideInset: CGFloat = 18
        let controlVerticalOffset: CGFloat = 14
        let shoulderY = deckTop + (deckHeight * 0.46)
        let utilityWidth = min(340, deckWidth * 0.36)
        let utilityHeight: CGFloat = 40
        let utilityY = deckTop + deckHeight + 8 + (utilityHeight / 2)
        let lowerTop = utilityY + (utilityHeight / 2) + 6
        let lowerHeight = max(112, contentHeight - lowerTop - 14)
        let dpadY = min(contentHeight - 56, lowerTop + (lowerHeight * 0.34) + controlVerticalOffset)
        let abxyY = dpadY
        let centerY = min(contentHeight - 34, lowerTop + (lowerHeight * 0.60))
        return NDSLandscapeLayoutMetrics(
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            deckWidth: deckWidth,
            deckHeight: deckHeight,
            deckTop: deckTop,
            shoulderWidth: shoulderWidth,
            shoulderHeight: shoulderHeight,
            shoulderY: shoulderY,
            utilityWidth: utilityWidth,
            utilityHeight: utilityHeight,
            utilityY: utilityY,
            dpadY: dpadY,
            abxyY: abxyY,
            centerY: centerY,
            dpadX: max((dpadSize / 2) + shellSideInset, deckMinX - (dpadSize / 2) - controlToDeckGap),
            abxyX: min(
                contentWidth - faceClusterHalfWidth - shellSideInset,
                deckMaxX + faceClusterHalfWidth + controlToDeckGap
            ),
            dpadSize: dpadSize,
            faceButtonDiameter: faceButtonDiameter,
            faceButtonSpacing: faceButtonSpacing,
            faceClusterHitSize: faceClusterHitSize
        )
    }

    private func deckMinX(for contentWidth: CGFloat, deckWidth: CGFloat) -> CGFloat {
        (contentWidth - deckWidth) / 2
    }

    private func deckMaxX(for contentWidth: CGFloat, deckWidth: CGFloat) -> CGFloat {
        deckMinX(for: contentWidth, deckWidth: deckWidth) + deckWidth
    }

    private func ndsLandscapeDeckLayer(metrics: NDSLandscapeLayoutMetrics) -> some View {
        let deckMinX = (metrics.contentWidth - metrics.deckWidth) / 2
        let deckMaxX = deckMinX + metrics.deckWidth
        return ZStack {
            ndsLandscapeDisplayDeck(metrics: metrics)

            ndsLandscapeSideShoulder(label: "L") {
                viewModel.handleButtonPress(.l1, pressed: true)
            } onRelease: {
                viewModel.handleButtonPress(.l1, pressed: false)
            }
            .frame(width: metrics.shoulderWidth, height: metrics.shoulderHeight)
            .position(
                x: max((metrics.shoulderWidth / 2) + 20, deckMinX - (metrics.shoulderWidth / 2) - 12),
                y: metrics.shoulderY
            )

            ndsLandscapeSideShoulder(label: "R") {
                viewModel.handleButtonPress(.r1, pressed: true)
            } onRelease: {
                viewModel.handleButtonPress(.r1, pressed: false)
            }
            .frame(width: metrics.shoulderWidth, height: metrics.shoulderHeight)
            .position(
                x: min(
                    metrics.contentWidth - (metrics.shoulderWidth / 2) - 20,
                    deckMaxX + (metrics.shoulderWidth / 2) + 12
                ),
                y: metrics.shoulderY
            )

            ndsLandscapeUtilityTray(width: metrics.utilityWidth, height: metrics.utilityHeight)
                .position(x: metrics.contentWidth * 0.5, y: metrics.utilityY)

            NDSDPadView(size: metrics.dpadSize) { button, pressed in
                viewModel.handleButtonPress(button, pressed: pressed)
            }
            .position(x: metrics.dpadX, y: metrics.dpadY)

            NDSFaceClusterView(
                onButton: { button, pressed in
                    viewModel.handleButtonPress(button, pressed: pressed)
                },
                buttonDiameter: metrics.faceButtonDiameter,
                buttonSpacing: metrics.faceButtonSpacing,
                showsBasePlate: false,
                minHitSize: metrics.faceClusterHitSize
            )
            .position(x: metrics.abxyX, y: metrics.abxyY)

            ndsLandscapeCenterSystemStrip()
                .position(x: metrics.contentWidth * 0.5, y: metrics.centerY)
        }
    }

    private func ndsLandscapeDisplayDeck(metrics: NDSLandscapeLayoutMetrics) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.black.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
                    .padding(3)
            )
            .overlay {
                ndsLandscapeDualScreens(
                    deckWidth: metrics.deckWidth,
                    deckHeight: metrics.deckHeight
                )
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
            .frame(width: metrics.deckWidth, height: metrics.deckHeight)
            .position(x: metrics.contentWidth * 0.5, y: metrics.deckTop + (metrics.deckHeight / 2))
    }

    private func ndsLandscapeDualScreens(deckWidth: CGFloat, deckHeight: CGFloat) -> some View {
        let innerPadding: CGFloat = 8
        let dividerWidth: CGFloat = 4
        let availableHeight = deckHeight - (innerPadding * 2)
        let maxSingleWidth = (deckWidth - (innerPadding * 2) - dividerWidth) / 2
        let singleHeight = availableHeight
        let singleWidth = min(maxSingleWidth, singleHeight * (256.0 / 192.0))

        return HStack(spacing: 0) {
            ndsLandscapeSingleScreen(
                width: singleWidth,
                height: singleHeight,
                interScreenSpacing: dividerWidth,
                isTouchScreen: false,
                drivesEmulation: true
            )

            Rectangle()
                .fill(Color.black.opacity(0.30))
                .frame(width: dividerWidth, height: max(1, singleHeight - 4))

            ndsLandscapeSingleScreen(
                width: singleWidth,
                height: singleHeight,
                interScreenSpacing: dividerWidth,
                isTouchScreen: true,
                drivesEmulation: false
            )
        }
        .padding(innerPadding)
    }

    private func ndsLandscapeSingleScreen(
        width: CGFloat,
        height: CGFloat,
        interScreenSpacing: CGFloat,
        isTouchScreen: Bool,
        drivesEmulation: Bool
    ) -> some View {
        let transform = ndsLandscapeScreenTransform(
            visibleWidth: width,
            visibleHeight: height,
            interScreenSpacing: interScreenSpacing,
            isTouchScreen: isTouchScreen
        )
        let screen = ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black)
            emulatorDisplayView(advancesEmulation: drivesEmulation)
                .frame(width: transform.sourceWidth, height: transform.sourceHeight)
                .offset(x: transform.xOffset, y: transform.yOffset)

            if isTouchScreen {
                NDSTouchScreenOverlayView { normalizedX, normalizedY, pressed in
                    if pressed {
                        viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                    } else {
                        viewModel.clearNDSTouch()
                    }
                }
                .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.70), lineWidth: 1.2)
        )
        return screen
    }

    private func ndsLandscapeUtilityTray(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ndsLandscapeUtilitySegment(icon: "square.and.arrow.down") { viewModel.quickSave() }
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1, height: height - 8)
            ndsLandscapeUtilitySegment(icon: "square.and.arrow.up") { viewModel.quickLoad() }
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1, height: height - 8)
            ndsLandscapeUtilitySegment(icon: "forward.fill") {
                cycleFastForwardSpeed()
            }
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1, height: height - 8)
            ZStack {
                ndsLandscapeUtilitySegment(icon: "speaker.wave.2") {
                    toggleGameSound()
                }
                if !gameSoundEnabled {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.22), lineWidth: 1.2)
                )
        )
    }

    private func ndsLandscapeUtilitySegment(icon: String, onPress: @escaping () -> Void) -> some View {
        Button(action: onPress) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.36))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func ndsLandscapeCenterSystemStrip() -> some View {
        HStack(spacing: 14) {
            Text("SELECT")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.black.opacity(0.34))

            HStack(spacing: 12) {
                ndsLandscapeRoundSystemButton(icon: "circle.fill", onPress: {
                    viewModel.handleButtonPress(.select, pressed: true)
                }, onRelease: {
                    viewModel.handleButtonPress(.select, pressed: false)
                })
                ndsLandscapeHomeButton(onPress: { showPauseMenu = true })
                ndsLandscapeRoundSystemButton(icon: "play.fill", onPress: {
                    viewModel.handleButtonPress(.start, pressed: true)
                }, onRelease: {
                    viewModel.handleButtonPress(.start, pressed: false)
                })
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.65))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.black.opacity(0.20), lineWidth: 1.2)
                    )
            )

            Text("START")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.black.opacity(0.34))
        }
        .frame(height: 44)
    }

    private func ndsLandscapeRoundSystemButton(
        icon: String,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            Circle()
                .fill(Color.white.opacity(isPressed ? 0.80 : 0.96))
                .overlay(Circle().stroke(Color.black.opacity(0.42), lineWidth: 1.4))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.32))
                )
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
    }

    private struct NDSLandscapeScreenTransform {
        let sourceWidth: CGFloat
        let sourceHeight: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat
    }

    private func ndsLandscapeScreenTransform(
        visibleWidth: CGFloat,
        visibleHeight: CGFloat,
        interScreenSpacing: CGFloat,
        isTouchScreen: Bool
    ) -> NDSLandscapeScreenTransform {
        switch viewModel.currentNDSDisplayLayout {
        case .stacked:
            let sourceHeight = visibleHeight * 2
            let yOffset = (sourceHeight - visibleHeight) / 2
            return NDSLandscapeScreenTransform(
                sourceWidth: visibleWidth,
                sourceHeight: sourceHeight,
                xOffset: 0,
                yOffset: isTouchScreen ? -yOffset : yOffset
            )
        case .sideBySide:
            let sourceWidth = (visibleWidth * 2) + interScreenSpacing
            let xOffset = (sourceWidth - visibleWidth) / 2
            return NDSLandscapeScreenTransform(
                sourceWidth: sourceWidth,
                sourceHeight: visibleHeight,
                xOffset: isTouchScreen ? -xOffset : xOffset,
                yOffset: 0
            )
        case .topOnly:
            return NDSLandscapeScreenTransform(
                sourceWidth: visibleWidth,
                sourceHeight: visibleHeight,
                xOffset: 0,
                yOffset: 0
            )
        case .bottomOnly:
            return NDSLandscapeScreenTransform(
                sourceWidth: visibleWidth,
                sourceHeight: visibleHeight,
                xOffset: 0,
                yOffset: 0
            )
        }
    }

    private func ndsLandscapeHomeButton(onPress: @escaping () -> Void) -> some View {
        NDSPressableControl(onPress: onPress, onRelease: {}) { isPressed in
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isPressed ? 0.80 : 0.96))
                .overlay(Capsule().stroke(Color.black.opacity(0.42), lineWidth: 1.4))
                .frame(width: 62, height: 36)
                .overlay(
                    Image(systemName: "house.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.32))
                )
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
    }

    private func ndsLandscapeSideShoulder(
        label: String,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isPressed ? 0.85 : 0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.38), lineWidth: 1.4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        .padding(1)
                )
                .overlay(
                    Text(label)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.30))
                )
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 1)
        }
    }

    private func ndsConsoleLayoutPortraitShell(
        width shellWidth: CGFloat,
        height shellHeight: CGFloat,
        viewportWidth: CGFloat,
        controllerBottomMargin: CGFloat
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.95),
                            Color(white: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 16)

            VStack(spacing: 4) {
                ndsDisplayStack(shellWidth: shellWidth)
                    .padding(.top, 30)
                    .padding(.bottom, 4)
                ndsCenterDots
                    .padding(.bottom, 4)
                ndsQuickStateRow
                    .padding(.bottom, 4)
                ndsControlDeck(
                    shellWidth: shellWidth,
                    viewportWidth: viewportWidth,
                    controllerBottomMargin: controllerBottomMargin
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(width: shellWidth, height: shellHeight)
    }

    private func isLandscape(_ geometry: GeometryProxy) -> Bool {
        guard hasUsableGeometry(geometry) else { return false }
        return geometry.size.width > geometry.size.height
    }

    private var shellPalette: ShellColorPalette { shellTheme.colorPalette }
    private var shellOverride: ShellThemeConsoleOverrides { shellTheme.override(for: ShellConsoleKind(platform: game.gamePlatform)) }

    private var ndsTopBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.title ?? "Nintendo DS")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
            }
            Spacer()
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
    }

    private func ndsDisplayStack(shellWidth: CGFloat) -> some View {
        let screenAreaWidth = safeFrameValue(shellWidth - 28, fallback: 220)
        let screenAreaHeight = safeFrameValue(min(screenAreaWidth * 1.62, 500), fallback: 320)
        let displayWidth = safeFrameValue(
            min(screenAreaWidth * 0.78, screenAreaHeight * (256.0 / 384.0)),
            fallback: 180
        )
        let displayHeight = safeFrameValue(displayWidth * (384.0 / 256.0), fallback: 270)
        let screenHalfHeight = safeFrameValue((displayHeight - 10) / 2, fallback: 120)
        let stackedTouchHeight = safeFrameValue(displayHeight / 2.0, fallback: 120)
        let portraitDisplayVerticalOffset: CGFloat = 12
        // Keep a light active-area trim for the decorative bezel in stacked mode.
        let stackedTouchTopInsetNormalized = safeFrameValue(6.0 / max(stackedTouchHeight, 1.0), fallback: 0.03)
        let stackedTouchBottomInsetNormalized = safeFrameValue(4.0 / max(stackedTouchHeight, 1.0), fallback: 0.02)
        let stackedTouchYBiasNormalized: CGFloat = 0

        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )

            ZStack {
                emulatorDisplayView
                    .frame(width: displayWidth, height: displayHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.82), lineWidth: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.black.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(1)
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .padding(8)
                    }
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.purple.opacity(0.22), lineWidth: 1.5)
                            .frame(width: displayWidth - 8, height: (displayHeight / 2) - 8)
                            .shadow(color: Color.purple.opacity(0.16), radius: 8, x: 0, y: 0)
                            .padding(.bottom, 4)
                    }

                Color.clear
                    .frame(width: displayWidth, height: displayHeight)
                    .overlay(alignment: .bottom) {
                        NDSTouchScreenOverlayView(
                            onStylus: { normalizedX, normalizedY, pressed in
                                if pressed {
                                    viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                                } else {
                                    viewModel.clearNDSTouch()
                                }
                            },
                            yBiasNormalized: stackedTouchYBiasNormalized,
                            topInsetNormalized: stackedTouchTopInsetNormalized,
                            bottomInsetNormalized: stackedTouchBottomInsetNormalized
                        )
                        .frame(width: displayWidth, height: displayHeight / 2)
                    }

                HStack(spacing: 8) {
                    ndsSideRail(buttonLabel: "L", topIcon: "line.3.horizontal", bottomIcon: "chevron.right") {
                        viewModel.handleButtonPress(.l1, pressed: true)
                    } onRelease: {
                        viewModel.handleButtonPress(.l1, pressed: false)
                    }
                    .frame(height: screenHalfHeight)
                    .offset(y: screenHalfHeight / 2 + 3)

                    Spacer(minLength: displayWidth)

                    ZStack {
                        ndsSideRail(buttonLabel: "R", topIcon: "camera.macro", bottomIcon: "speaker.wave.2.fill") {
                            viewModel.handleButtonPress(.r1, pressed: true)
                        } onRelease: {
                            viewModel.handleButtonPress(.r1, pressed: false)
                        }
                        if !gameSoundEnabled {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.red)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .offset(y: -20)
                        }
                    }
                    .frame(height: screenHalfHeight)
                    .offset(y: screenHalfHeight / 2 + 3)
                }
                .frame(width: displayWidth + 96, height: displayHeight)
            }
            .frame(width: displayWidth + 90, height: displayHeight)
            .offset(y: portraitDisplayVerticalOffset)
        }
        .frame(width: screenAreaWidth, height: screenAreaHeight)
    }

    private var ndsCenterDots: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color.black.opacity(0.55)).frame(width: 5, height: 5)
                }
            }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color.black.opacity(0.45)).frame(width: 5, height: 5)
                }
            }
        }
        .padding(.top, 2)
    }

    private var ndsQuickStateRow: some View {
        HStack(spacing: 10) {
            ndsQuickStateButton(
                title: "SAVE",
                systemName: "square.and.arrow.down.fill",
                tint: .green
            ) {
                viewModel.quickSave()
            }
            ndsQuickStateButton(
                title: "LOAD",
                systemName: "square.and.arrow.up.fill",
                tint: .orange
            ) {
                viewModel.quickLoad()
            }
        }
        .padding(.top, 2)
        .padding(.bottom, -4)
    }

    private enum NDSControlSizePreset {
        case compact
        case standard
        case large
    }

    private struct NDSControlMetrics {
        let dpadSize: CGFloat
        let faceDiameter: CGFloat
        let faceSpacing: CGFloat
        let systemDiameter: CGFloat
        let homeWidth: CGFloat
        let homeHeight: CGFloat
        let sideMargin: CGFloat
        let centerGap: CGFloat
        let arcOffset: CGFloat
        let switchToControlsGap: CGFloat
    }

    private func ndsControlMetrics(for viewportWidth: CGFloat) -> NDSControlMetrics {
        let preset: NDSControlSizePreset
        if viewportWidth > 430 {
            preset = .large
        } else if viewportWidth < 390 {
            preset = .compact
        } else {
            preset = .standard
        }

        switch preset {
        case .compact:
            return NDSControlMetrics(
                dpadSize: 140,
                faceDiameter: 60,
                faceSpacing: 13,
                systemDiameter: 48,
                homeWidth: 84,
                homeHeight: 42,
                sideMargin: 30,
                centerGap: 18,
                arcOffset: 22,
                switchToControlsGap: 34
            )
        case .standard:
            return NDSControlMetrics(
                dpadSize: 150,
                faceDiameter: 64,
                faceSpacing: 14,
                systemDiameter: 52,
                homeWidth: 90,
                homeHeight: 46,
                sideMargin: 32,
                centerGap: 20,
                arcOffset: 26,
                switchToControlsGap: 40
            )
        case .large:
            return NDSControlMetrics(
                dpadSize: 162,
                faceDiameter: 68,
                faceSpacing: 16,
                systemDiameter: 56,
                homeWidth: 96,
                homeHeight: 48,
                sideMargin: 34,
                centerGap: 24,
                arcOffset: 30,
                switchToControlsGap: 44
            )
        }
    }

    private func ndsControlDeck(shellWidth: CGFloat, viewportWidth: CGFloat, controllerBottomMargin: CGFloat) -> some View {
        let metrics = ndsControlMetrics(for: viewportWidth)
        let minimumDistanceBetweenControls: CGFloat = 16
        let baseDPadSize: CGFloat = metrics.dpadSize
        let faceDiameter: CGFloat = metrics.faceDiameter
        let faceSpacing: CGFloat = metrics.faceSpacing
        let baseFaceClusterWidth = (faceDiameter + faceSpacing) * 2
        let sideMargin = metrics.sideMargin
        let availableMainRowWidth = max(0, shellWidth - (sideMargin * 2))
        let spacingBudget = max(14, min(metrics.centerGap, 26))
        let fitScale = min(
            1.0,
            max(0.86, (availableMainRowWidth - spacingBudget) / (baseDPadSize + baseFaceClusterWidth))
        )
        let dpadSize = baseDPadSize * fitScale
        let faceClusterWidth = baseFaceClusterWidth * fitScale
        let faceButtonDiameter = max(58, faceDiameter * fitScale)
        let faceButtonSpacing = max(10, faceSpacing * fitScale)
        let systemButtonDiameter = max(44, metrics.systemDiameter * fitScale)
        let homeWidth = max(68, metrics.homeWidth * fitScale)
        let homeHeight = max(40, metrics.homeHeight * fitScale)
        let systemTouchDiameter = max(66, systemButtonDiameter + 12)
        let homeTouchWidth = max(92, homeWidth + 14)
        let homeTouchHeight = max(54, homeHeight + 12)
        let targetEdgeInset = max(sideMargin, 32)
        let minDPadCenterX = targetEdgeInset + (dpadSize / 2)
        let maxABXYCenterX = shellWidth - targetEdgeInset - (faceClusterWidth / 2)
        let availableCenterDistance = max(0, maxABXYCenterX - minDPadCenterX)
        let desiredCenterDistance = min(228, max(188, availableCenterDistance))
        let dpadCenterX = max(minDPadCenterX, (shellWidth - desiredCenterDistance) / 2)
        let abxyCenterX = min(maxABXYCenterX, dpadCenterX + desiredCenterDistance)
        let controlsRowHeight = max(dpadSize, faceClusterWidth) + 26
        let rowCenterY = controlsRowHeight / 2
        let plateInset: CGFloat = 12
        let utilityIconSize = max(34.0, min(40.0, 36.0 * fitScale + 2.0))
        let plateMinX = dpadCenterX - (dpadSize / 2) - plateInset
        let plateMaxX = abxyCenterX + (faceClusterWidth / 2) + plateInset
        let plateWidth = max(0, plateMaxX - plateMinX)
        let plateCenterX = (plateMinX + plateMaxX) / 2
        let topControlsInset = max(24.0, metrics.switchToControlsGap - 8.0)
        let bottomControlsInset = max(8.0, min(16.0, controllerBottomMargin))
        assert(
            dpadSize + minimumDistanceBetweenControls + faceClusterWidth <= availableMainRowWidth,
            "NDS controls overlap: insufficient horizontal room for D-pad and ABXY cluster."
        )

        return VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .frame(width: plateWidth, height: controlsRowHeight)
                        .position(x: plateCenterX, y: rowCenterY)

                    NDSDPadView(size: dpadSize) { button, pressed in
                        viewModel.handleButtonPress(button, pressed: pressed)
                    }
                    .frame(width: dpadSize, height: dpadSize)
                    .position(x: dpadCenterX, y: rowCenterY)

                    NDSFaceClusterView(
                        onButton: { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        },
                        buttonDiameter: faceButtonDiameter,
                        buttonSpacing: faceButtonSpacing,
                        showsBasePlate: false
                    )
                    .frame(width: faceClusterWidth, height: faceClusterWidth)
                    .position(x: abxyCenterX, y: rowCenterY)
                }
                .frame(width: shellWidth, height: controlsRowHeight)

                ndsSystemButtonsStrip(
                    systemButtonDiameter: systemButtonDiameter,
                    homeWidth: homeWidth,
                    homeHeight: homeHeight,
                    systemTouchDiameter: systemTouchDiameter,
                    homeTouchWidth: homeTouchWidth,
                    homeTouchHeight: homeTouchHeight
                )
                    .padding(.horizontal, 28)

                HStack(spacing: 10) {
                    gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green, customSize: utilityIconSize) {
                        viewModel.quickSave()
                    }
                    gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange, customSize: utilityIconSize) {
                        viewModel.quickLoad()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            .padding(.top, topControlsInset)
            .padding(.bottom, bottomControlsInset)
        }
        .frame(maxWidth: .infinity)
    }

    private func ndsQuickStateButton(
        title: String,
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .light))
                Text(title)
                    .font(.system(size: 10, weight: .light))
            }
            .foregroundColor(tint.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.90))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func gbUtilityIcon(systemName: String, tint: Color, customSize: CGFloat? = nil, action: @escaping () -> Void) -> AnyView {
        let utilitySize = customSize ?? safeThemeDimension(shellOverride.utilityButtonSize ?? shellTheme.controlStyle.utilityButtonSize)
        let iconColor = shellPalette.utilityIcon.color
        let strokeColor = shellPalette.utilityStroke.color
        let fillStart = shellPalette.utilityFillStart.color
        let fillEnd = shellPalette.utilityFillEnd.color
        let accentGlow = shellPalette.utilityGlow.color
        let accentStroke = shellPalette.shellAccent.color

        if isGBCMinimalShellTheme {
            return AnyView(
                ShellUtilityIconButton(
                    systemName: systemName,
                    action: action,
                    style: .minimalMaterial,
                    size: utilitySize,
                    iconColor: Color.white.opacity(0.88),
                    strokeColor: Color.white.opacity(0.14),
                    tint: tint,
                    fillStart: .clear,
                    fillEnd: .clear,
                    accentStroke: .clear,
                    accentGlow: .clear,
                    glowEnabled: false
                )
            )
        } else {
            return AnyView(
                ShellUtilityIconButton(
                    systemName: systemName,
                    action: action,
                    style: .neonCircle,
                    size: utilitySize,
                    iconColor: iconColor,
                    strokeColor: strokeColor,
                    tint: tint,
                    fillStart: fillStart,
                    fillEnd: fillEnd,
                    accentStroke: accentStroke,
                    accentGlow: accentGlow,
                    glowEnabled: shellTheme.controlStyle.glowEnabled
                )
                .scaleEffect(0.98)
            )
        }
    }

    private func ndsSystemButtonsStrip(
        systemButtonDiameter: CGFloat,
        homeWidth: CGFloat,
        homeHeight: CGFloat,
        systemTouchDiameter: CGFloat,
        homeTouchWidth: CGFloat,
        homeTouchHeight: CGFloat
    ) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("SELECT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.60))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 32, alignment: .trailing)
                NDSPressableControl(
                    onPress: { viewModel.handleButtonPress(.select, pressed: true) },
                    onRelease: { viewModel.handleButtonPress(.select, pressed: false) }
                ) { isPressed in
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.84 : 0.98))
                        .overlay(Circle().stroke(Color.black.opacity(0.58), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(isPressed ? 0.0 : 0.15), radius: 4, x: 0, y: 2)
                        .frame(width: systemButtonDiameter * 0.8, height: systemButtonDiameter * 0.8)
                        .frame(width: systemTouchDiameter * 0.8, height: systemTouchDiameter * 0.8)
                }
            }

            Spacer(minLength: 6)

            NDSPressableControl(onPress: { showPauseMenu = true }, onRelease: {}) { isPressed in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.86 : 0.98))
                    .overlay(Capsule(style: .continuous).stroke(Color.black.opacity(0.48), lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(isPressed ? 0.0 : 0.15), radius: 4, x: 0, y: 2)
                    .frame(width: homeWidth * 0.85, height: homeHeight * 0.85)
                    .frame(width: homeTouchWidth * 0.85, height: homeTouchHeight * 0.85)
                    .overlay(
                        Image(systemName: "house.fill")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(Color.black.opacity(0.50))
                    )
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                NDSPressableControl(
                    onPress: { viewModel.handleButtonPress(.start, pressed: true) },
                    onRelease: { viewModel.handleButtonPress(.start, pressed: false) }
                ) { isPressed in
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.84 : 0.98))
                        .overlay(Circle().stroke(Color.black.opacity(0.58), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(isPressed ? 0.0 : 0.15), radius: 4, x: 0, y: 2)
                        .frame(width: systemButtonDiameter * 0.8, height: systemButtonDiameter * 0.8)
                        .frame(width: systemTouchDiameter * 0.8, height: systemTouchDiameter * 0.8)
                }
                Text("START")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.60))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                )
        )
        .frame(height: max(systemTouchDiameter, homeTouchHeight))
    }

    private func shellSystemButtonsRow(
        theme: ShellSystemButtonTheme,
        onMenu: @escaping () -> Void,
        onSelectPress: @escaping (Bool) -> Void,
        onStartPress: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            ShellSystemButton(theme: theme, label: "MENU", icon: "house.fill", onPress: onMenu, onRelease: {})
            Spacer()
            ShellSystemButton(theme: theme, label: "SELECT", icon: nil) {
                onSelectPress(true)
            } onRelease: {
                onSelectPress(false)
            }
            ShellSystemButton(theme: theme, label: "START", icon: nil) {
                onStartPress(true)
            } onRelease: {
                onStartPress(false)
            }
        }
        .frame(height: 34)
    }

    private func shellSystemButtonsRowLandscapeCompact(
        theme: ShellSystemButtonTheme,
        onMenu: @escaping () -> Void,
        onSelectPress: @escaping (Bool) -> Void,
        onStartPress: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ShellSystemButton(theme: theme, label: "MENU", icon: "house.fill", onPress: onMenu, onRelease: {})
            ShellSystemButton(theme: theme, label: "SELECT", icon: nil) {
                onSelectPress(true)
            } onRelease: {
                onSelectPress(false)
            }
            ShellSystemButton(theme: theme, label: "START", icon: nil) {
                onStartPress(true)
            } onRelease: {
                onStartPress(false)
            }
        }
        .frame(height: 34)
    }

    private func shellLandscapeMenuButton(theme: ShellSystemButtonTheme, onMenu: @escaping () -> Void) -> some View {
        HStack {
            ShellSystemButton(
                theme: theme,
                label: "MENU",
                icon: "line.3.horizontal",
                minWidth: 110,
                controlHeight: 44,
                fontSize: 14,
                knobDiameter: 28,
                horizontalPadding: 16,
                onPress: onMenu,
                onRelease: {}
            )
            Spacer(minLength: 0)
        }
        .frame(height: 44)
    }

    private func shellLandscapeSelectStartRow(
        theme: ShellSystemButtonTheme,
        onSelectPress: @escaping (Bool) -> Void,
        onStartPress: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ShellSystemButton(
                theme: theme,
                label: "SELECT",
                icon: "circle.fill",
                minWidth: 90,
                controlHeight: 44,
                fontSize: 14,
                knobDiameter: 28,
                horizontalPadding: 16
            ) {
                onSelectPress(true)
            } onRelease: {
                onSelectPress(false)
            }
            ShellSystemButton(
                theme: theme,
                label: "START",
                icon: "play.fill",
                minWidth: 90,
                controlHeight: 44,
                fontSize: 14,
                knobDiameter: 28,
                horizontalPadding: 16
            ) {
                onStartPress(true)
            } onRelease: {
                onStartPress(false)
            }
        }
        .frame(height: 44)
    }

    private func gbaLandscapeSelectStartRow(
        theme: ShellSystemButtonTheme,
        onSelectPress: @escaping (Bool) -> Void,
        onStartPress: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 18) {
            ShellSystemButton(
                theme: theme,
                label: "SELECT",
                minWidth: 70,
                controlHeight: 28,
                fontSize: 11,
                knobDiameter: 0,
                horizontalPadding: 12,
                showsKnob: false
            ) {
                onSelectPress(true)
            } onRelease: {
                onSelectPress(false)
            }
            ShellSystemButton(
                theme: theme,
                label: "START",
                minWidth: 70,
                controlHeight: 28,
                fontSize: 11,
                knobDiameter: 0,
                horizontalPadding: 12,
                showsKnob: false
            ) {
                onStartPress(true)
            } onRelease: {
                onStartPress(false)
            }
        }
        .frame(height: 28)
    }

    private func gbaLandscapeUtilityTray(iconSize: CGFloat) -> some View {
        HStack(spacing: 14) {
            gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green, customSize: iconSize) {
                viewModel.quickSave()
            }
            gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange, customSize: iconSize) {
                viewModel.quickLoad()
            }
            gbUtilityIcon(systemName: "forward.fill", tint: .yellow, customSize: iconSize) {
                cycleFastForwardSpeed()
            }
            ZStack {
                gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan, customSize: iconSize) {
                    toggleGameSound()
                }
                if !gameSoundEnabled {
                    Image(systemName: "xmark")
                        .font(.system(size: iconSize * 0.8, weight: .light))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    private func ndsLandscapeMenuCompactButton(theme: ShellSystemButtonTheme, onMenu: @escaping () -> Void) -> some View {
        HStack {
            ShellSystemButton(
                theme: theme,
                label: "Menu",
                icon: "line.3.horizontal",
                minWidth: 96,
                controlHeight: 40,
                fontSize: 13,
                knobDiameter: 24,
                horizontalPadding: 12,
                onPress: onMenu,
                onRelease: {}
            )
            Spacer(minLength: 0)
        }
        .frame(height: 40)
    }

    private func ndsLandscapeSelectStartCompactRow(
        theme: ShellSystemButtonTheme,
        onSelectPress: @escaping (Bool) -> Void,
        onStartPress: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ShellSystemButton(
                theme: theme,
                label: "Sel",
                icon: "circle.fill",
                minWidth: 76,
                controlHeight: 40,
                fontSize: 13,
                knobDiameter: 24,
                horizontalPadding: 10
            ) {
                onSelectPress(true)
            } onRelease: {
                onSelectPress(false)
            }
            ShellSystemButton(
                theme: theme,
                label: "Start",
                icon: "play.fill",
                minWidth: 76,
                controlHeight: 40,
                fontSize: 13,
                knobDiameter: 24,
                horizontalPadding: 10
            ) {
                onStartPress(true)
            } onRelease: {
                onStartPress(false)
            }
        }
        .frame(height: 40)
    }

    private func gbConsoleLayoutLandscape(in geometry: GeometryProxy) -> AnyView {
        guard hasUsableGeometry(geometry) else { return AnyView(Color.black) }
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let outerHorizontalMargin: CGFloat = 8
        let gbDPadScale: CGFloat = (game.gamePlatform == .GBC) ? 0.72 : 0.76
        let gbFaceScale: CGFloat = (game.gamePlatform == .GBC) ? 0.70 : 0.74
        let shellWidth = safeFrameValue(max(560, min(geometry.size.width - safeLeading - safeTrailing - (outerHorizontalMargin * 2), 980.0)), fallback: 560)
        let shellHeight = safeFrameValue(max(286, min(geometry.size.height - 8, 438.0)), fallback: 286)
        let innerWidth = safeFrameValue(shellWidth - 18, fallback: 542)
        let columnGap: CGFloat = 10
        let dpadSize = 182 * gbDPadScale
        let faceSize = 190 * gbFaceScale
        let leftControlMinWidth = max(dpadSize + 2, 156)
        let rightControlMinWidth = max(faceSize + 2, 156)
        let minDisplayPanelWidth: CGFloat = 340
        let maxDisplayPanelWidth: CGFloat = 460
        let maxSideColumnWidth = safeFrameValue(max(164, (innerWidth - minDisplayPanelWidth - (columnGap * 2)) / 2), fallback: 164)
        let sideColumnWidth = safeFrameValue(min(max(leftControlMinWidth, rightControlMinWidth), maxSideColumnWidth), fallback: 180)
        let centerPanelWidth = safeFrameValue(min(
            maxDisplayPanelWidth,
            max(minDisplayPanelWidth, innerWidth - (sideColumnWidth * 2) - (columnGap * 2))
        ), fallback: minDisplayPanelWidth)
        let portraitReferenceShellWidth = safeFrameValue(max(220, min(geometry.size.height - 18, 430.0)), fallback: 220)
        let portraitReferenceDisplayWidth = safeFrameValue(portraitReferenceShellWidth - 28, fallback: 180)
        let portraitMatchedScreenWidth = safeFrameValue(
            min(
                portraitReferenceDisplayWidth - 8,
                portraitReferenceDisplayWidth * ((game.gamePlatform == .GBC) ? 0.70 : 0.77)
            ),
            fallback: 120
        )
        let screenWidth = safeFrameValue(min(centerPanelWidth - 18, portraitMatchedScreenWidth), fallback: 180)
        let screenHeight = safeFrameValue(screenWidth * (144.0 / 160.0), fallback: 120)
        let screenSafeInset: CGFloat = 16
        let screenPanelTopInset: CGFloat = 10
        let mainControlHeight = safeFrameValue(max(screenHeight + 18, max(dpadSize, faceSize) + 34), fallback: 190)
        let screenBottomAlignment = safeFrameValue(screenPanelTopInset + screenHeight, fallback: screenHeight)
        let controlBottomInset = safeFrameValue(max(0, mainControlHeight - screenBottomAlignment), fallback: 0)
        let dpadTopInset = safeFrameValue(max(0, screenBottomAlignment - dpadSize), fallback: 0)
        let faceTopInset = safeFrameValue(max(0, screenBottomAlignment - faceSize), fallback: 0)
        let lowerBandTopSpacing: CGFloat = 16
        let utilityIconSize: CGFloat = 36
        let centerSafeWidth = safeFrameValue(max(centerPanelWidth, screenWidth + (screenSafeInset * 2)), fallback: centerPanelWidth)

        return AnyView(
        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: game.gamePlatform == .GBC
                                ? [
                                    Color(red: 0.99, green: 0.31, blue: 0.85).opacity(0.18),
                                    Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.22),
                                    Color(red: 0.43, green: 0.91, blue: 0.98).opacity(0.12)
                                ]
                                : [
                                    Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.12),
                                    Color(red: 0.12, green: 0.10, blue: 0.22).opacity(0.20)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.04)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.purple.opacity(0.22), Color.pink.opacity(0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.purple.opacity(0.18), radius: 20, x: 0, y: 8)

                VStack(spacing: 0) {
                    HStack(spacing: columnGap) {
                        VStack(spacing: 0) {
                            Spacer(minLength: dpadTopInset)
                            GBDPadView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbDPadScale)
                            .frame(width: dpadSize, height: dpadSize)
                            Spacer(minLength: controlBottomInset)
                        }
                        .frame(width: sideColumnWidth, height: mainControlHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(red: 0.07, green: 0.09, blue: 0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            emulatorDisplayView
                                .frame(width: screenWidth, height: screenHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.08), Color.black.opacity(0.25)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .padding(.top, screenPanelTopInset)
                        }
                        .frame(width: centerPanelWidth, height: mainControlHeight)

                        VStack(spacing: 0) {
                            Spacer(minLength: faceTopInset)
                            GBFaceButtonsView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbFaceScale)
                            .frame(width: faceSize, height: faceSize)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            Spacer(minLength: controlBottomInset)
                        }
                        .frame(width: sideColumnWidth, height: mainControlHeight)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(height: mainControlHeight)

                    Spacer(minLength: lowerBandTopSpacing)

                    HStack(alignment: .bottom, spacing: columnGap) {
                        VStack {
                            Spacer(minLength: 0)
                            shellLandscapeMenuButton(theme: .neoGlass) {
                                showPauseMenu = true
                            }
                            .frame(width: sideColumnWidth - 12, alignment: .leading)
                        }
                        .frame(width: sideColumnWidth, alignment: .leading)

                        VStack(spacing: 18) {
                            gbaLandscapeSelectStartRow(theme: .neoGlass) { pressed in
                                viewModel.handleButtonPress(.select, pressed: pressed)
                            } onStartPress: { pressed in
                                viewModel.handleButtonPress(.start, pressed: pressed)
                            }

                            gbaLandscapeUtilityTray(iconSize: utilityIconSize)
                        }
                        .frame(width: centerSafeWidth)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                        Color.clear
                            .frame(width: sideColumnWidth, height: 1)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, 10)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 4)

            statusBar
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
        }
        .padding(.leading, safeLeading)
        .padding(.trailing, safeTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        )
    }

    @ViewBuilder
    private func gbaConsoleLayoutLandscape(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let outerHorizontalMargin: CGFloat = 8
        let shellWidth = safeFrameValue(max(560, min(geometry.size.width - safeLeading - safeTrailing - (outerHorizontalMargin * 2), 980.0)), fallback: 560)
        let shellHeight = safeFrameValue(max(286, min(geometry.size.height - 8, 438.0)), fallback: 286)
        let layoutScale = safeFrameValue(min(1.0, max(0.86, (shellHeight - 250.0) / 120.0)), fallback: 1.0)
        let gbaDPadScale: CGFloat = 0.72 * layoutScale
        let gbaFaceScale: CGFloat = 0.72 * layoutScale
        let innerWidth = safeFrameValue(shellWidth - 18, fallback: 542)
        let columnGap: CGFloat = 10
        let dpadSize = 182 * gbaDPadScale
        let faceSize = 190 * gbaFaceScale
        let leftControlMinWidth = max(dpadSize + 2, 156)
        let rightControlMinWidth = max(faceSize + 2, 156)
        let minDisplayPanelWidth: CGFloat = 360
        let maxDisplayPanelWidth: CGFloat = 540
        let maxSideColumnWidth = max(164, (innerWidth - minDisplayPanelWidth - (columnGap * 2)) / 2)
        let sideColumnWidth = safeFrameValue(min(max(leftControlMinWidth, rightControlMinWidth), maxSideColumnWidth), fallback: 180)
        let displayPanelWidth = safeFrameValue(min(
            maxDisplayPanelWidth,
            max(minDisplayPanelWidth, innerWidth - (sideColumnWidth * 2) - (columnGap * 2))
        ), fallback: minDisplayPanelWidth)
        let screenSafeInset: CGFloat = 16
        let portraitReferenceShellWidth = safeFrameValue(max(220, min(geometry.size.height - 18, 430.0)), fallback: 220)
        let portraitMatchedScreenWidth = safeFrameValue(
            min(portraitReferenceShellWidth - 16, portraitReferenceShellWidth * 0.84),
            fallback: 120
        )
        let screenWidth = safeFrameValue(min(displayPanelWidth - 18, portraitMatchedScreenWidth), fallback: 180)
        let screenHeight = safeFrameValue(screenWidth * (160.0 / 240.0), fallback: 120)
        let mainControlHeight = safeFrameValue(max(screenHeight + 16, max(dpadSize, faceSize) + 34), fallback: 184)
        let lowerBandTopSpacing = safeFrameValue(max(14, 18 * layoutScale), fallback: 16)
        let systemToUtilitySpacing = safeFrameValue(max(14, 20 * layoutScale), fallback: 18)
        let utilityIconSize = safeFrameValue(max(34, min(38, 36 * layoutScale + 1)), fallback: 36)
        let centerSafeWidth = safeFrameValue(max(displayPanelWidth, screenWidth + (screenSafeInset * 2)), fallback: displayPanelWidth)
        let screenPanelTopInset: CGFloat = 36
        let screenBottomAlignment = safeFrameValue(screenPanelTopInset + screenHeight, fallback: screenHeight)
        let controlBottomInset = safeFrameValue(max(0, mainControlHeight - screenBottomAlignment), fallback: 0)
        let dpadTopInset = safeFrameValue(max(0, screenBottomAlignment - dpadSize), fallback: 0)
        let faceTopInset = safeFrameValue(max(0, screenBottomAlignment - faceSize), fallback: 0)

        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Advance")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.12, blue: 0.58), Color(red: 0.12, green: 0.04, blue: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.05), Color.clear, Color.black.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
                VStack {
                    HStack {
                        GBAShoulderBar(label: "L") {
                            viewModel.handleButtonPress(.l1, pressed: true)
                        } onRelease: { viewModel.handleButtonPress(.l1, pressed: false) }
                        Spacer()
                        GBAShoulderBar(label: "R") {
                            viewModel.handleButtonPress(.r1, pressed: true)
                        } onRelease: { viewModel.handleButtonPress(.r1, pressed: false) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    Spacer()
                }

                VStack(spacing: 0) {
                    HStack(spacing: columnGap) {
                        VStack(spacing: 0) {
                            Spacer(minLength: dpadTopInset)
                            GBALightDPadView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbaDPadScale)
                            .frame(width: dpadSize, height: dpadSize)
                            Spacer(minLength: controlBottomInset)
                        }
                        .frame(width: sideColumnWidth, height: mainControlHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack(alignment: .top) {
                            Color.black.opacity(0.95)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                        .padding(2)
                                )
                            emulatorDisplayView
                                .frame(width: screenWidth, height: screenHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                                .padding(.top, screenPanelTopInset)
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: safeFrameValue(screenWidth - 10, fallback: 1), height: 1)
                                .padding(.top, 14)
                        }
                        .frame(width: displayPanelWidth, height: mainControlHeight)

                        VStack(spacing: 0) {
                            Spacer(minLength: faceTopInset)
                            GBAFaceButtonsView { button, pressed in
                                viewModel.handleButtonPress(button, pressed: pressed)
                            }
                            .scaleEffect(gbaFaceScale)
                            .frame(width: faceSize, height: faceSize)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            Spacer(minLength: controlBottomInset)
                        }
                        .frame(width: sideColumnWidth, height: mainControlHeight)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(height: mainControlHeight)

                    Spacer(minLength: lowerBandTopSpacing)

                    HStack(alignment: .bottom, spacing: columnGap) {
                        VStack {
                            Spacer(minLength: 0)
                            shellLandscapeMenuButton(theme: .darkPurple) {
                                showPauseMenu = true
                            }
                            .frame(width: sideColumnWidth - 12, alignment: .leading)
                        }
                        .frame(width: sideColumnWidth, alignment: .leading)

                        VStack(spacing: systemToUtilitySpacing) {
                            gbaLandscapeSelectStartRow(theme: .darkPurple) { pressed in
                                viewModel.handleButtonPress(.select, pressed: pressed)
                            } onStartPress: { pressed in
                                viewModel.handleButtonPress(.start, pressed: pressed)
                            }

                            gbaLandscapeUtilityTray(iconSize: utilityIconSize)
                        }
                        .frame(width: centerSafeWidth)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                        Color.clear
                            .frame(width: sideColumnWidth, height: 1)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(.horizontal, 10)
                .padding(.top, 22)
                .padding(.bottom, 8)
            }
            .frame(width: shellWidth, height: shellHeight)
            .padding(.bottom, 4)

            statusBar
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
        }
        .padding(.leading, safeLeading)
        .padding(.trailing, safeTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var emulatorDisplayView: some View {
        emulatorDisplayView(advancesEmulation: true)
    }

    private func emulatorDisplayView(advancesEmulation: Bool) -> some View {
        ZStack {
            if let renderer = viewModel.renderer {
                MetalView(
                    metalRenderer: renderer,
                    tick: advancesEmulation ? viewModel.tick : nil,
                    renderScale: viewModel.currentRenderScale,
                    targetFrameDuration: { viewModel.targetFrameTime }
                )
            } else {
                retroMindPlaceholderView
            }
        }
    }

    private var retroMindPlaceholderView: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(time * 1.8)
            let pulseSecondary = 0.5 + 0.5 * sin(time * 2.4 + 1.1)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.09),
                        Color(red: 0.06, green: 0.03, blue: 0.12),
                        Color(red: 0.02, green: 0.09, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                .clear,
                                Color.white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        VStack(spacing: 4) {
                            ForEach(0..<72, id: \.self) { _ in
                                Rectangle()
                                    .frame(height: 1)
                            }
                        }
                    )
                    .opacity(0.10)

                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(Color.purple.opacity(0.26 + pulse * 0.22), lineWidth: 1.2)
                    .blur(radius: 0.3)
                    .padding(12)

                Circle()
                    .fill(Color.purple.opacity(0.16 + pulseSecondary * 0.08))
                    .blur(radius: 36)
                    .scaleEffect(0.72 + pulseSecondary * 0.18)

                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.9), Color(red: 0.72, green: 0.56, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("RetroMind")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(loadingPlatformName.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .kerning(1.2)
                        .foregroundColor(Color.white.opacity(0.72))
                    Text("Initializing Core")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.82))

                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(0.35 + 0.5 * max(0, sin(time * 3.0 - Double(index) * 0.6))))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.top, 2)

                    Text(viewModel.statusMessage.isEmpty ? "Core Ready" : viewModel.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.66))
                        .lineLimit(1)
                        .padding(.top, 1)
                }
                .padding(24)
                .multilineTextAlignment(.center)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func cycleFastForwardSpeed() {
        guard let currentIndex = Self.fastForwardSpeeds.firstIndex(of: fastForwardSpeed) else {
            fastForwardSpeed = Self.fastForwardSpeeds[0]
            viewModel.setFastForward(fastForwardSpeed)
            return
        }

        let nextIndex = (currentIndex + 1) % Self.fastForwardSpeeds.count
        fastForwardSpeed = Self.fastForwardSpeeds[nextIndex]
        viewModel.setFastForward(fastForwardSpeed)
    }

    private func toggleGameSound() {
        gameSoundEnabled.toggle()
        viewModel.setGameSound(enabled: gameSoundEnabled)
    }

    private var loadingPlatformName: String {
        switch game.gamePlatform {
        case .GB:
            return "Game Boy"
        case .GBC:
            return "Game Boy Color"
        case .GBA:
            return "Game Boy Advance"
        case .NDS:
            return "Nintendo DS"
        case .NES:
            return "Nintendo Entertainment System"
        case .GENESIS:
            return "Genesis"
        case .PS1:
            return "PlayStation"
        case .PS2:
            return "PlayStation 2"
        case ._3DS:
            return "Nintendo 3DS"
        case .none:
            return "Emulator"
        }
    }

    private func retroBootDurationSeconds(for platform: Platform?) -> Double {
        switch platform {
        case .GB, .GBC:
            return 0.74
        case .GBA:
            return 0.66
        case .NDS:
            return 0.86
        default:
            return 0.68
        }
    }

    private struct CartridgeLaunchStyle {
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let labelHeight: CGFloat
        let slotWidth: CGFloat
    }

    private var cartridgeLaunchStyle: CartridgeLaunchStyle {
        switch game.gamePlatform {
        case .GB, .GBC:
            return CartridgeLaunchStyle(
                width: 196,
                height: 232,
                cornerRadius: 22,
                labelHeight: 144,
                slotWidth: 156
            )
        case .GBA:
            return CartridgeLaunchStyle(
                width: 220,
                height: 154,
                cornerRadius: 24,
                labelHeight: 92,
                slotWidth: 186
            )
        case .NDS:
            return CartridgeLaunchStyle(
                width: 170,
                height: 104,
                cornerRadius: 20,
                labelHeight: 54,
                slotWidth: 132
            )
        default:
            return CartridgeLaunchStyle(
                width: 188,
                height: 172,
                cornerRadius: 22,
                labelHeight: 92,
                slotWidth: 152
            )
        }
    }

    private func cartridgeLaunchOverlay(in geometry: GeometryProxy) -> some View {
        let style = cartridgeLaunchStyle
        let isNDSLandscapeIntro = game.gamePlatform == .NDS && isLandscape(geometry)
        let insertionProgress = max(0.0, min(1.0, cartridgeInsertionProgress))
        let revealProgress = max(0.0, min(1.0, cartridgeRevealProgress))
        let bootProgress = max(0.0, min(1.0, retroBootProgress))
        let depthProgress = 1.0 - insertionProgress
        let easedDepth = depthProgress * depthProgress
        let travel = max(108.0, min(180.0, geometry.size.height * 0.18))
        let finalLift = max(18.0, min(36.0, geometry.size.height * 0.035)) * revealProgress
        let centerYOffset: CGFloat = {
            if isNDSLandscapeIntro {
                return -max(10.0, min(26.0, geometry.size.height * 0.03)) - (finalLift * 0.35)
            }
            return -max(58.0, min(118.0, geometry.size.height * 0.11)) - finalLift
        }()
        let centerXOffset: CGFloat = {
            guard isNDSLandscapeIntro else { return 0 }
            let safeLeading = geometry.safeAreaInsets.leading
            let safeTrailing = geometry.safeAreaInsets.trailing
            let cameraSideExclusionInset: CGFloat = 34
            let cameraOnLeadingSide = safeLeading > safeTrailing
            let cameraLeadingInset = cameraOnLeadingSide ? cameraSideExclusionInset : 0
            let cameraTrailingInset = cameraOnLeadingSide ? 0 : cameraSideExclusionInset
            return ndsLandscapeHorizontalOffset(
                safeLeading: safeLeading,
                safeTrailing: safeTrailing,
                cameraLeadingInset: cameraLeadingInset,
                cameraTrailingInset: cameraTrailingInset
            )
        }()
        let sinkDistance = style.height * 0.46 * revealProgress
        let cartridgeY = (-travel + (travel * 2.0 * insertionProgress)) + centerYOffset + sinkDistance
        let slotY = travel + (style.height * 0.34) + centerYOffset
        let tilt = -6.0 * (1.0 - insertionProgress)
        let horizontalDrift = 7.0 * (1.0 - insertionProgress)
        let cartridgeScale = 1.025 - (0.065 * insertionProgress)
        let perspectivePitch = 24.0 * easedDepth
        let perspectiveYaw = -10.0 * easedDepth
        let perspectiveRoll = -4.0 * depthProgress
        let sideCompression = 1.0 - (0.13 * easedDepth)
        let cardShadowOpacity = 0.20 + (0.22 * depthProgress)
        let cardVisibility = max(0.0, 1.0 - revealProgress * 1.2 - (showRetroBootSequence ? (0.20 + 0.65 * bootProgress) : 0))
        return ZStack {
            Color.black.opacity(max(0.02, (0.24 - (0.12 * insertionProgress)) * (1.0 - 0.92 * revealProgress)))
                .ignoresSafeArea()

            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.75))
                    .frame(width: style.slotWidth, height: 18)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.16), Color.black.opacity(0.35)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.overlay)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 4)
                    .offset(y: slotY)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(showCartridgePowerOnGlow ? 0.22 : 0.06), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: style.slotWidth * 0.82, height: 8)
                            .offset(y: slotY - 2)
                    )

                cartridgeBody(
                    style: style,
                    insertionProgress: insertionProgress,
                    revealProgress: revealProgress
                )
                    .frame(width: style.width, height: style.height)
                    .offset(y: cartridgeY)
                    .offset(x: horizontalDrift)
                    .rotationEffect(.degrees(tilt), anchor: .bottom)
                    .rotationEffect(.degrees(perspectiveRoll), anchor: .bottom)
                    .rotation3DEffect(
                        .degrees(perspectivePitch),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.78
                    )
                    .rotation3DEffect(
                        .degrees(perspectiveYaw),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .bottomTrailing,
                        perspective: 0.78
                    )
                    .scaleEffect(
                        x: cartridgeScale * sideCompression * (1.0 + 0.06 * revealProgress),
                        y: cartridgeScale * (1.0 + 0.02 * revealProgress),
                        anchor: .bottom
                    )
                    .shadow(color: Color.black.opacity(cardShadowOpacity), radius: 12, x: 0, y: 8)
                    .opacity(cardVisibility)
                    .blur(radius: 4.0 * revealProgress, opaque: false)
            }
            .offset(x: centerXOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showCartridgePowerOnGlow {
                RadialGradient(
                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.06), Color.clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: max(120, min(240, geometry.size.width * 0.34))
                )
                .offset(x: centerXOffset)
                .ignoresSafeArea()
                .transition(.opacity)
            }

            Color.black.opacity(0.20 * revealProgress)
                .ignoresSafeArea()
                .blendMode(.multiply)
        }
        .opacity(cartridgeOverlayOpacity)
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func retroBootSequenceView(
        in geometry: GeometryProxy,
        style: CartridgeLaunchStyle,
        progress: CGFloat,
        topInset: CGFloat
    ) -> some View {
        let p = max(0.0, min(1.0, progress))
        let panelWidth = min(geometry.size.width * 0.52, max(170, style.slotWidth * 1.42))
        let panelHeight = min(geometry.size.height * 0.20, max(96, style.labelHeight * 0.62))
        let panelOpacity = min(1.0, max(0.0, (p + 0.12) / 0.34)) * (1.0 - max(0.0, (p - 0.84) / 0.16))

        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                switch game.gamePlatform {
                case .GB, .GBC:
                    gbBootSequence(progress: p)
                case .GBA:
                    gbaBootSequence(progress: p)
                case .NDS:
                    ndsBootSequence(progress: p)
                default:
                    defaultBootSequence(progress: p)
                }
            }
            .frame(width: panelWidth, height: panelHeight)
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, topInset)
        .opacity(Double(panelOpacity))
    }

    private func retroBootTopInset(in geometry: GeometryProxy) -> CGFloat {
        let baseRatio: CGFloat
        switch game.gamePlatform {
        case .NDS:
            baseRatio = 0.13
        case .GB, .GBC:
            baseRatio = 0.17
        case .GBA:
            baseRatio = 0.15
        default:
            baseRatio = 0.16
        }

        let topSafe = geometry.safeAreaInsets.top
        let candidate = geometry.size.height * baseRatio
        return max(topSafe + 16, min(candidate, geometry.size.height * 0.24))
    }

    private func gbBootSequence(progress: CGFloat) -> some View {
        let p = max(0.0, min(1.0, progress))
        let logoDropProgress = min(1.0, p / 0.56)
        let logoOffset = (1.0 - logoDropProgress) * -58
        let logoOpacity = min(1.0, max(0.0, (p - 0.10) / 0.22))
        let fadeOut = 1.0 - max(0.0, (p - 0.80) / 0.20)

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.73, green: 0.82, blue: 0.55))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), .clear, Color.black.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Nintendo")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(Color.black.opacity(0.56))
                .offset(y: logoOffset)
                .opacity(Double(logoOpacity * fadeOut))
        }
        .padding(12)
    }

    private func gbaBootSequence(progress: CGFloat) -> some View {
        let p = max(0.0, min(1.0, progress))
        let logoOpacity = min(1.0, max(0.0, (p - 0.14) / 0.32))
        let logoScale = 0.94 + (0.06 * min(1.0, p / 0.52))
        let fadeOut = 1.0 - max(0.0, (p - 0.82) / 0.18)

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.94))
            RadialGradient(
                colors: [Color.purple.opacity(0.26), Color.clear],
                center: .center,
                startRadius: 8,
                endRadius: 140
            )

            VStack(spacing: 4) {
                Text("GAME BOY")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))
                Text("ADVANCE")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.72, green: 0.60, blue: 0.98))
                    .tracking(1.0)
            }
            .opacity(Double(logoOpacity * fadeOut))
            .scaleEffect(logoScale)
        }
        .padding(12)
    }

    private func ndsBootSequence(progress: CGFloat) -> some View {
        let p = max(0.0, min(1.0, progress))
        let logoOpacity = min(1.0, max(0.0, (p - 0.10) / 0.24))
        let flashOpacity = max(0.0, 1.0 - abs((p - 0.42) / 0.18))
        let fadeOut = 1.0 - max(0.0, (p - 0.86) / 0.14)

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.96))

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 126, height: 24)
                Text("Nintendo DS")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.62))
                    .opacity(Double(logoOpacity * fadeOut))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 126, height: 24)
            }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(Double(0.36 * flashOpacity)))
        }
        .padding(12)
    }

    private func defaultBootSequence(progress: CGFloat) -> some View {
        let p = max(0.0, min(1.0, progress))
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.88))

            Text("Power On")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .opacity(Double(min(1.0, max(0.0, (p - 0.08) / 0.20))))
        }
        .padding(12)
    }

    private func cartridgeBody(
        style: CartridgeLaunchStyle,
        insertionProgress: CGFloat,
        revealProgress: CGFloat
    ) -> some View {
        let depthProgress = 1.0 - insertionProgress
        let visualDepth = min(1.0, depthProgress + revealProgress * 0.55)
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.94), Color(white: 0.86).opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.42), lineWidth: 1.6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24 + (0.28 * visualDepth)),
                                    Color.clear,
                                    Color.black.opacity(0.10 + (0.22 * visualDepth))
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.overlay)
                )
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)

            if game.gamePlatform == .GB || game.gamePlatform == .GBC {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: style.width * 0.44, height: 10)
                    .offset(y: 12)
            } else if game.gamePlatform == .NDS {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .frame(width: style.width * 0.36, height: 8)
                    .offset(y: 10)
            }

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .overlay {
                        cartridgeLabelContent
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(3)
                    }
                    .frame(height: style.labelHeight)

                Text(loadingPlatformName.uppercased())
                    .font(.system(size: 10, weight: .light))
                    .kerning(0.7)
                    .foregroundColor(.black.opacity(0.48))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(12)
            .padding(.top, game.gamePlatform == .NDS ? 8 : 12)
        }
    }

    @ViewBuilder
    private var cartridgeLabelContent: some View {
        ZStack(alignment: .bottomLeading) {
            cartridgeCoverPreview

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title ?? "Untitled")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)
                Text(loadingPlatformName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.80))
                    .lineLimit(1)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var cartridgeCoverPreview: some View {
#if canImport(UIKit)
        if let data = game.coverImage, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            cartridgeCoverFallback
        }
#elseif canImport(AppKit)
        if let data = game.coverImage, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            cartridgeCoverFallback
        }
#else
        cartridgeCoverFallback
#endif
    }

    private var cartridgeCoverFallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.32, green: 0.23, blue: 0.48), Color(red: 0.20, green: 0.29, blue: 0.53)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white.opacity(0.34))
        }
    }

    private var statusBar: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isRunning ? "Running" : "Paused")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()

                if showFPSMeter {
                    Text("FPS: \(viewModel.currentFPS)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if fastForwardSpeed > 1 {
                    Text("\(fastForwardSpeed)x")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.yellow)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }

    private var fpsOverlayChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "speedometer")
                .font(.system(size: 10, weight: .semibold))
            Text("FPS \(max(0, viewModel.currentFPS))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(.white.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
    }

    #if DEBUG
    private var performanceHUDOverlay: some View {
        let snapshot = performanceProfiler.hudSnapshot
        return VStack(alignment: .leading, spacing: 4) {
            Text(
                String(
                    format: "FPS %.1f  P95 %.1fms  Jank %d/m",
                    snapshot.fps,
                    snapshot.p95FrameMs,
                    snapshot.jankPerMinute
                )
            )
            Text(
                String(
                    format: "Mem %.0fMB  Peak %.0fMB  Warn %d",
                    snapshot.memoryMB,
                    snapshot.peakMemoryMB,
                    snapshot.memoryWarnings
                )
            )
            Text("Thermal \(thermalLabel(snapshot.thermalState))  LPM \(snapshot.lowPowerModeEnabled ? "ON" : "OFF")")
            Text(
                String(
                    format: "Scale %.2f  Skip %d",
                    snapshot.qualityProfile.renderScale,
                    snapshot.qualityProfile.frameSkip
                )
            )
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundColor(.white.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    #endif
    
    private var pauseMenuOverlay: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isNDSLandscape = game.gamePlatform == .NDS && isLandscape
            let safeLeading = geometry.safeAreaInsets.leading
            let safeTrailing = geometry.safeAreaInsets.trailing

            // For NDS landscape, position within the shell's center lane
            let calculatedShellWidth = min(geometry.size.width - safeLeading - safeTrailing - 12, 1180.0)
            let innerWidth = calculatedShellWidth - 28
            let sideColumnWidth: CGFloat = 118
            let centerGap: CGFloat = 10
            let calculatedCenterLaneWidth = max(560, min(920, innerWidth - (sideColumnWidth * 2) - (centerGap * 2)))
            let shellHorizontalPosition = (geometry.size.width - calculatedShellWidth) / 2
            let centerLanePosition = shellHorizontalPosition + 14 + sideColumnWidth + centerGap
            let ndsLandscapePauseNudge: CGFloat = isNDSLandscape ? -84 : 0
            let centerLaneOffset = isNDSLandscape
                ? (centerLanePosition - (geometry.size.width - calculatedCenterLaneWidth) / 2) + ndsLandscapePauseNudge
                : 0
            let centerLaneWidth = isNDSLandscape ? calculatedCenterLaneWidth : 560.0
            let horizontalInset: CGFloat = isLandscape ? 40 : 28
            let availablePanelWidth = safeFrameValue(
                geometry.size.width - safeLeading - safeTrailing - horizontalInset,
                fallback: geometry.size.width - horizontalInset
            )

            let pausePanelWidth = isLandscape
                ? safeFrameValue(
                    max(
                        centerLaneWidth,
                        min(
                            isNDSLandscape ? centerLaneWidth : geometry.size.width - ((safeLeading + safeTrailing) * 2) - 40,
                            1180.0
                        )
                    ),
                    fallback: centerLaneWidth
                )
                : safeFrameValue(
                    min(max(availablePanelWidth, 280), 620),
                    fallback: 360
                )

            ZStack {
                AppColors.background.opacity(heavyUIEffectsEnabled ? 0.42 : 0.56)
                    .ignoresSafeArea()
                    .overlay {
                        if heavyUIEffectsEnabled {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.16)
                        } else {
                            Color.black.opacity(0.08)
                        }
                    }
                    .onTapGesture { }

                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(screenString("gameplay.pause.title", "Game Paused"))
                                .font(SubpageUI.Font.title)
                                .foregroundColor(AppColors.textPrimary)
                            Text(game.title ?? screenString("gameplay.pause.current_game", "Current game"))
                                .font(SubpageUI.Font.subtitle)
                                .foregroundColor(AppColors.textMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            viewModel.resumeEmulation()
                            showPauseMenu = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(AppColors.surfaceLight.opacity(0.65))
                                .clipShape(Circle())
                        }
                    }

                    if !viewModel.statusMessage.isEmpty {
                        Text(localizedPauseStatusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                    }

                    pauseActionButton(title: screenString("gameplay.pause.resume", "Resume"), icon: "play.fill", style: .primary) {
                        triggerHaptic(.light)
                        viewModel.resumeEmulation()
                        showPauseMenu = false
                    }

                    HStack(spacing: 10) {
                        pauseActionButton(title: screenString("gameplay.pause.quick_save", "Quick Save"), icon: "square.and.arrow.down.fill") {
                            triggerHaptic(.medium)
                            viewModel.quickSave()
                            saveSlotSummaries = viewModel.saveSlotSummaries()
                        }
                        pauseActionButton(title: screenString("gameplay.pause.quick_load", "Quick Load"), icon: "square.and.arrow.up.fill") {
                            triggerHaptic(.medium)
                            viewModel.quickLoad()
                        }
                    }

                    pauseActionButton(title: screenString("gameplay.pause.restart", "Restart Game"), icon: "arrow.counterclockwise") {
                        restartGameFromPause()
                    }

                    HStack(spacing: 10) {
                        pauseActionButton(title: pauseSheetMode == .advanced ? screenString("gameplay.pause.back", "Back") : screenString("gameplay.pause.save_states", "Save States"), icon: pauseSheetMode == .advanced ? "chevron.left" : "tray.full.fill") {
                            withAnimation(.easeOut(duration: 0.2)) {
                                if pauseSheetMode == .advanced {
                                    pauseSheetMode = .quick
                                    showSaveSlotsPanel = false
                                } else {
                                    pauseSheetMode = .advanced
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            ForEach(Self.fastForwardSpeeds, id: \.self) { speed in
                                Button {
                                    triggerHaptic(.light)
                                    fastForwardSpeed = speed
                                    viewModel.setFastForward(fastForwardSpeed)
                                } label: {
                                    Text("\(speed)x")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(fastForwardSpeed == speed ? .white : AppColors.textPrimary)
                                        .frame(width: 44, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(fastForwardSpeed == speed ? AppColors.primary : AppColors.surfaceLight.opacity(0.55))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(AppColors.surface.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if pauseSheetMode == .advanced {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                pauseActionButton(title: showSaveSlotsPanel ? screenString("gameplay.pause.hide_saves", "Hide Saves") : screenString("gameplay.pause.manage_saves", "Manage Saves"), icon: "tray.full.fill") {
                                    saveSlotSummaries = viewModel.saveSlotSummaries()
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showSaveSlotsPanel.toggle()
                                    }
                                }
                                pauseActionButton(title: screenString("gameplay.pause.controls", "Controls"), icon: "gamecontroller") {
                                    // Reserved for future in-game controls editor
                                }
                            }

                            if showSaveSlotsPanel {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(screenString("gameplay.pause.save_states", "Save States"))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        Text(screenString("gameplay.pause.slot_overview", "Quick + 10 Slots"))
                                            .font(.system(size: 11))
                                            .foregroundColor(AppColors.textMuted)
                                    }

                                    ScrollView {
                                        LazyVStack(spacing: 10) {
                                            ForEach(saveSlotSummaries) { summary in
                                                saveSlotCard(summary)
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                    .frame(maxHeight: 260)
                                }
                                .padding(14)
                                .background(AppColors.surface.opacity(0.88))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.surfaceLight.opacity(0.75), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }

                    pauseActionButton(title: screenString("gameplay.pause.exit_to_library", "Exit to Library"), icon: "xmark", style: .destructive) {
                        startTask?.cancel()
                        startTask = nil
                        viewModel.stopEmulation()
                        onExit()
                    }
                }
                .padding(16)
                .frame(width: pausePanelWidth)
                .subpagePopup(cornerRadius: 22)
                .offset(x: centerLaneOffset)
                .padding(.horizontal, isLandscape ? 0 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var launchStatePickerOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.46)
                .ignoresSafeArea()
                .overlay(.ultraThinMaterial.opacity(0.14))
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(screenString("gameplay.pause.resume_from_save_state", "Resume From Save State?"))
                        .font(SubpageUI.Font.title)
                        .foregroundColor(AppColors.textPrimary)
                    Text(screenString("gameplay.pause.resume_from_save_state_message", "Choose a save to continue, or start fresh."))
                        .font(SubpageUI.Font.body)
                        .foregroundColor(AppColors.textMuted)
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(saveSlotSummaries.enumerated()), id: \.element.id) { index, summary in
                            Button {
                                viewModel.loadSlotSummary(summary)
                                showLaunchStatePicker = false
                            } label: {
                                saveSlotListRow(summary, mode: .launchPicker, isRecommended: index == 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)

                HStack(spacing: 10) {
                    pauseActionButton(title: screenString("gameplay.pause.start_fresh", "Start Fresh"), icon: "sparkles") {
                        showLaunchStatePicker = false
                    }
                    pauseActionButton(title: screenString("gameplay.pause.open_pause_menu", "Open Pause Menu"), icon: "line.3.horizontal") {
                        showLaunchStatePicker = false
                        showPauseMenu = true
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 620)
            .subpagePopup(cornerRadius: 24)
            .padding(.horizontal, 18)
        }
    }

    private var launchFailureOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.55)
                .ignoresSafeArea()
                .overlay(.ultraThinMaterial.opacity(0.16))

            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(AppColors.warning)
                Text(screenString("gameplay.pause.unable_to_start", "Unable to Start Game"))
                    .font(SubpageUI.Font.title)
                    .foregroundColor(AppColors.textPrimary)
                Text(viewModel.statusMessage)
                    .font(SubpageUI.Font.body)
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    pauseActionButton(title: screenString("gameplay.pause.retry", "Retry"), icon: "arrow.clockwise", style: .primary) {
                        beginLaunchSequence(allowResumeFlow: true)
                    }
                    pauseActionButton(title: screenString("gameplay.pause.back", "Back"), icon: "xmark") {
                        onExit()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 420)
            .subpagePopup(cornerRadius: 22)
            .padding(.horizontal, 18)
        }
    }

    private var localizedPauseStatusMessage: String {
        switch viewModel.statusMessage {
        case "Paused":
            return screenString("gameplay.pause.paused", "Paused")
        default:
            return viewModel.statusMessage
        }
    }

    private func screenString(_ key: String, _ fallback: String) -> String {
        L10n.string(key, table: "Screens", fallback: fallback, languageManager: languageManager)
    }

    private func screenFormat(_ key: String, _ fallback: String, _ value: CVarArg) -> String {
        L10n.format(key, value, table: "Screens", fallback: fallback, languageManager: languageManager)
    }

    private enum PauseActionStyle {
        case primary, normal, destructive
    }

    private func pauseActionButton(title: String, icon: String, style: PauseActionStyle = .normal, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(foregroundColor(for: style))
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor(for: style))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(for: style), lineWidth: 1)
        )
    }

    private func foregroundColor(for style: PauseActionStyle) -> Color {
        switch style {
        case .primary: return .white
        case .normal: return AppColors.textPrimary
        case .destructive: return AppColors.error
        }
    }

    private func backgroundColor(for style: PauseActionStyle) -> Color {
        switch style {
        case .primary: return AppColors.primary
        case .normal: return AppColors.surfaceLight.opacity(0.55)
        case .destructive: return AppColors.error.opacity(0.10)
        }
    }

    private func borderColor(for style: PauseActionStyle) -> Color {
        switch style {
        case .primary: return AppColors.primary.opacity(0.9)
        case .normal: return AppColors.surfaceLight.opacity(0.8)
        case .destructive: return AppColors.error.opacity(0.35)
        }
    }

    private func triggerHaptic(_ style: HapticStyle) {
        #if canImport(UIKit)
        let generatorStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:
            generatorStyle = .light
        case .medium:
            generatorStyle = .medium
        }
        let generator = UIImpactFeedbackGenerator(style: generatorStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func playCartridgeInsertionFeedback() {
        triggerHaptic(.medium)
        #if canImport(AVFoundation) && canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        let activeRouteKind = AudioEngine.routeKind(for: session.currentRoute.outputs)
        guard activeRouteKind == .speakerOrWired else { return }
        let played = BootClickAudioPlayer.shared.play()
        if !played {
            #if canImport(AudioToolbox)
            AudioServicesPlaySystemSound(1104)
            #endif
        }
        #elseif canImport(AudioToolbox) && canImport(UIKit)
        AudioServicesPlaySystemSound(1104)
        #endif
    }

    private enum SaveSlotRowMode {
        case pauseMenu
        case launchPicker
    }

    @ViewBuilder
    private func saveSlotCard(_ summary: SaveStateSlotSummary) -> some View {
        saveSlotListRow(summary, mode: .pauseMenu)
    }

    @ViewBuilder
    private func saveSlotListRow(_ summary: SaveStateSlotSummary, mode: SaveSlotRowMode, isRecommended: Bool = false) -> some View {
        HStack(spacing: 12) {
            saveSlotThumbnail(summary)
                .frame(width: mode == .launchPicker ? 96 : 112, height: mode == .launchPicker ? 60 : 72)

            if mode == .launchPicker {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(summary.isQuickSlot ? screenString("gameplay.pause.quick_save", "Quick Save") : screenFormat("gameplay.pause.slot_format", "Slot %@", summary.displayName))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        consoleIdentityBadge
                        if isRecommended {
                            Text(screenString("gameplay.pause.recommended", "Recommended"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppColors.primary.opacity(0.10)))
                        }
                    }
                    Text(summary.metadata?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? screenString("gameplay.pause.no_save_yet", "No save yet"))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textMuted)
                        .lineLimit(1)

                    Text(game.title ?? screenString("gameplay.pause.unknown_game", "Unknown Game"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceLight.opacity(0.45))
                    .clipShape(Circle())
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(summary.isQuickSlot ? screenString("gameplay.pause.quick_save", "Quick Save") : screenFormat("gameplay.pause.slot_format", "Slot %@", summary.displayName))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        consoleIdentityBadge

                        Text(summary.isEmpty ? screenString("gameplay.pause.empty", "Empty") : screenString("gameplay.pause.saved", "Saved"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(summary.isEmpty ? AppColors.textMuted : AppColors.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.surfaceLight.opacity(summary.isEmpty ? 0.35 : 0.55)))
                    }

                    Text(summary.metadata?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? screenString("gameplay.pause.no_save_yet", "No save yet"))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textMuted)
                        .lineLimit(1)

                    Text(game.title ?? screenString("gameplay.pause.unknown_game", "Unknown Game"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        compactSlotIconButton(systemImage: "square.and.arrow.down") {
                            if summary.isQuickSlot {
                                viewModel.quickSave()
                            } else {
                                viewModel.saveState(slot: summary.slot)
                            }
                            saveSlotSummaries = viewModel.saveSlotSummaries()
                        }
                        compactSlotIconButton(systemImage: "play.fill", disabled: summary.isEmpty) {
                            viewModel.loadSlotSummary(summary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(AppColors.background.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var consoleIdentityBadge: some View {
        if let console = game.consoleIdentity {
            Text(console.systemCode)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(console.accentColor))
        }
    }

    @ViewBuilder
    private func compactSlotButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.surfaceLight.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.surfaceLight.opacity(0.75), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func compactSlotIconButton(systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.surfaceLight.opacity(0.55))
                HStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                    if systemImage == "play.fill" {
                        Text("Load")
                            .font(.system(size: 11, weight: .semibold))
                    } else if systemImage == "square.and.arrow.down" {
                        Text("Save")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundColor(AppColors.textPrimary)
            }
            .frame(width: 62, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.surfaceLight.opacity(0.75), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func saveSlotThumbnail(_ summary: SaveStateSlotSummary) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight.opacity(0.7), AppColors.surface.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            #if canImport(UIKit)
            if let image = saveSlotUIImage(summary: summary) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(2)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
            }
            #else
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textMuted)
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
        )
    }

    #if canImport(UIKit)
    private func saveSlotUIImage(summary: SaveStateSlotSummary) -> UIImage? {
        if let data = summary.screenshotData, let image = UIImage(data: data) {
            return image
        }
        guard !summary.isEmpty, let romHash = currentROMHashForSaveStates else { return nil }
        if let data = SaveStateStorage.shared.latestScreenshot(for: romHash), let image = UIImage(data: data) {
            return image
        }
        return nil
    }
    #endif

    private var currentROMHashForSaveStates: String? {
        guard let romPath = game.romPath else { return nil }
        return URL(fileURLWithPath: romPath).deletingPathExtension().lastPathComponent
    }
}

#if canImport(AVFoundation) && canImport(UIKit)
@MainActor
private final class BootClickAudioPlayer {
    static let shared = BootClickAudioPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat?
    private let clickBuffer: AVAudioPCMBuffer?

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else {
            clickBuffer = nil
            return
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        clickBuffer = Self.makeClickBuffer(format: format)
    }

    @discardableResult
    func play() -> Bool {
        guard let buffer = clickBuffer else { return false }
        configureAudioSession()

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return false
            }
        }

        if player.isPlaying {
            player.stop()
        }
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
        return true
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // Route through media volume so the click is audible on real devices.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetoothA2DP])
        try? session.setActive(true)
    }

    private static func makeClickBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let durationSeconds = 0.040
        let frameCount = AVAudioFrameCount(max(1, Int(format.sampleRate * durationSeconds)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData?.pointee else {
            return nil
        }

        buffer.frameLength = frameCount
        let sr = format.sampleRate

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sr
            let envelope = exp(-t * 85.0)
            let toneA = sin(2.0 * .pi * 2_200.0 * t)
            let toneB = sin(2.0 * .pi * 1_250.0 * t)
            let sample = (toneA * 0.72 + toneB * 0.28) * envelope * 0.95
            channelData[frame] = Float(sample)
        }

        return buffer
    }
}
#endif

private struct ShellUtilityIconButton: View {
    enum Style {
        case minimalMaterial
        case neonCircle
    }

    let systemName: String
    let action: () -> Void
    let style: Style
    let size: CGFloat
    let iconColor: Color
    let strokeColor: Color
    let tint: Color
    let fillStart: Color
    let fillEnd: Color
    let accentStroke: Color
    let accentGlow: Color
    let glowEnabled: Bool

    var body: some View {
        let buttonSize = max(20, min(size.isFinite ? size : 32, 80))

        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(backgroundShape(size: buttonSize))
                .overlay(strokeOverlays)
                .shadow(color: glowEnabled && style == .neonCircle ? accentGlow : .clear, radius: 10, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func backgroundShape(size: CGFloat) -> some View {
        switch style {
        case .minimalMaterial:
            Circle().fill(.ultraThinMaterial)
        case .neonCircle:
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            strokeColor.opacity(0.18),
                            fillEnd,
                            fillStart
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: max(size * 0.75, 12)
                    )
                )
        }
    }

    @ViewBuilder
    private var strokeOverlays: some View {
        switch style {
        case .minimalMaterial:
            Circle().stroke(strokeColor, lineWidth: 1)
        case .neonCircle:
            ZStack {
                Circle().stroke(strokeColor, lineWidth: 1)
                Circle().stroke(tint.opacity(0.12), lineWidth: 0.5)
                Circle().stroke(accentStroke.opacity(0.22), lineWidth: 1)
            }
        }
    }
}

private enum NDSScreenSlicePosition {
    case top
    case bottom
}

private struct NDSScreenFrame<Content: View>: View {
    let label: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.black.opacity(0.85), lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.black.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .padding(1)
                )
                .overlay(content().clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous)).padding(2))
        }
    }
}

private struct NDSTouchScreenOverlayView: View {
    let onStylus: (_ normalizedX: CGFloat, _ normalizedY: CGFloat, _ pressed: Bool) -> Void
    var yBiasNormalized: CGFloat = 0
    var topInsetNormalized: CGFloat = 0
    var bottomInsetNormalized: CGFloat = 0
    @State private var isPressed = false
    @State private var stylusLocation: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    if let stylusLocation {
                        stylusIndicator
                            .position(x: stylusLocation.x, y: stylusLocation.y)
                            .allowsHitTesting(false)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let size = proxy.size
                            guard size.width > 0, size.height > 0 else { return }
                            let rawX = value.location.x / size.width
                            let rawY = value.location.y / size.height
                            let topInset = max(0, min(0.45, topInsetNormalized))
                            let bottomInset = max(0, min(0.45, bottomInsetNormalized))
                            let minY = topInset
                            let maxY = 1.0 - bottomInset
                            guard rawX >= 0, rawX <= 1, rawY >= minY, rawY <= maxY else {
                                stylusLocation = nil
                                if isPressed {
                                    isPressed = false
                                    onStylus(0, 0, false)
                                }
                                return
                            }

                            let usableHeight = max(0.001, 1.0 - topInset - bottomInset)
                            let adjustedY = (rawY - topInset) / usableHeight
                            let x = max(0, min(1, rawX))
                            let y = max(0, min(1, adjustedY + yBiasNormalized))
                            let quantizedX = (x * 255.0).rounded() / 255.0
                            let quantizedY = (y * 191.0).rounded() / 191.0
                            isPressed = true
                            stylusLocation = CGPoint(
                                x: quantizedX * size.width,
                                y: quantizedY * size.height
                            )
                            onStylus(quantizedX, quantizedY, true)
                        }
                        .onEnded { _ in
                            if isPressed {
                                isPressed = false
                                onStylus(0, 0, false)
                                let releasePoint = stylusLocation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    if !isPressed, stylusLocation == releasePoint {
                                        stylusLocation = nil
                                    }
                                }
                            }
                        }
                )
                .onDisappear {
                    if isPressed {
                        isPressed = false
                        stylusLocation = nil
                        onStylus(0, 0, false)
                    }
                }
        }
    }

    private var stylusIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.72))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.2))
            Circle()
                .fill(Color.black.opacity(0.95))
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.55), radius: 1.5, x: 0, y: 0)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
    }
}

private struct NDSPressableControl<Content: View>: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onPress: () -> Void
    let onRelease: () -> Void
    let content: (Bool) -> Content
    @State private var pressTracker = TouchPressTracker()
    private let hapticManager = HapticManager.shared

    init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void, @ViewBuilder content: @escaping (Bool) -> Content) {
        self.onPress = onPress
        self.onRelease = onRelease
        self.content = content
    }

    var body: some View {
        content(pressTracker.isPressed)
            .scaleEffect(pressTracker.isPressed ? shellTheme.controlStyle.pressScale : 1.0)
            .animation(
                .spring(response: max(0.16, shellTheme.animationStyle.tapDuration * 1.5), dampingFraction: 0.82),
                value: pressTracker.isPressed
            )
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                switch pressTracker.transition(for: pressing) {
                case .pressed:
                    hapticManager.buttonPressed()
                    onPress()
                case .released:
                    hapticManager.buttonReleased()
                    onRelease()
                case .none:
                    break
                }
            }, perform: {})
            .onDisappear {
                if pressTracker.reset() {
                    onRelease()
                }
            }
    }
}

private struct NDSDPadView: View {
    let size: CGFloat
    let onButton: (EmulatorButton, Bool) -> Void

    init(size: CGFloat = 150, onButton: @escaping (EmulatorButton, Bool) -> Void) {
        self.size = size
        self.onButton = onButton
    }

    private var armWidth: CGFloat { size * (42.0 / 150.0) }
    private var centerHubDiameter: CGFloat { size * (42.0 / 150.0) }
    private var cornerRadius: CGFloat { max(10, size * (10.0 / 150.0)) }
    private var zoneSize: CGFloat { max(80.0, size * 0.56) }
    private var zoneOffset: CGFloat { (size * 0.5) - (zoneSize * 0.30) }

    var body: some View {
        ZStack {
            NDSCrossShape(size: size, armWidth: armWidth, cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    NDSCrossShape(size: size, armWidth: armWidth, cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.78), lineWidth: 2.2)
                )
                .overlay(
                    NDSCrossShape(size: size, armWidth: armWidth, cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .padding(1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.94), Color.white.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.40), lineWidth: 1.4))
                .frame(width: centerHubDiameter, height: centerHubDiameter)

            NDSDPadPressZone(button: .dpadUp, onButton: onButton)
                .frame(width: zoneSize, height: zoneSize)
                .offset(y: -zoneOffset)

            NDSDPadPressZone(button: .dpadDown, onButton: onButton)
                .frame(width: zoneSize, height: zoneSize)
                .offset(y: zoneOffset)

            NDSDPadPressZone(button: .dpadLeft, onButton: onButton)
                .frame(width: zoneSize, height: zoneSize)
                .offset(x: -zoneOffset)

            NDSDPadPressZone(button: .dpadRight, onButton: onButton)
                .frame(width: zoneSize, height: zoneSize)
                .offset(x: zoneOffset)
        }
        .frame(width: size, height: size)
    }
}

private enum NDSDPadDirection {
    case up
    case down
    case left
    case right
}

private struct NDSCrossShape: Shape {
    let size: CGFloat
    let armWidth: CGFloat
    let cornerRadius: CGFloat

    func path(in _: CGRect) -> Path {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let vertical = CGRect(x: rect.midX - armWidth / 2, y: 0, width: armWidth, height: size)
        let horizontal = CGRect(x: 0, y: rect.midY - armWidth / 2, width: size, height: armWidth)

        var path = Path()
        path.addPath(Path(roundedRect: vertical, cornerRadius: cornerRadius))
        path.addPath(Path(roundedRect: horizontal, cornerRadius: cornerRadius))
        return path
    }
}

private struct NDSDPadPressZone: View {
    let button: EmulatorButton
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        NDSPressableControl(
            onPress: { onButton(button, true) },
            onRelease: { onButton(button, false) }
        ) { isPressed in
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(isPressed ? 0.10 : 0.001))
                .contentShape(Rectangle())
        }
    }
}

private struct NDSFaceClusterView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void
    var buttonDiameter: CGFloat = 64
    var buttonSpacing: CGFloat = 14
    var showsBasePlate: Bool = true
    var minHitSize: CGFloat = 78

    private var offsetAmount: CGFloat { buttonSpacing + (buttonDiameter / 2) }
    private var clusterSize: CGFloat { (offsetAmount + (buttonDiameter / 2)) * 2 }

    var body: some View {
        ZStack {
            if showsBasePlate {
                Circle()
                    .fill(shellTheme.colorPalette.shellHighlight.color.opacity(0.08))
                    .frame(width: max(clusterSize - 40, 100), height: max(clusterSize - 40, 100))
                    .overlay(
                        Circle()
                            .stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.2), lineWidth: 1)
                    )
            }
            round(.x, "X")
                .offset(y: -offsetAmount)
            round(.y, "Y")
                .offset(x: -offsetAmount)
            round(.a, "A")
                .offset(x: offsetAmount)
            round(.b, "B")
                .offset(y: offsetAmount)
        }
        .frame(width: clusterSize, height: clusterSize)
    }

    private func round(_ button: EmulatorButton, _ label: String) -> some View {
        let touchSize = max(minHitSize, buttonDiameter + 8)
        return NDSPressableControl(
            onPress: { onButton(button, true) },
            onRelease: { onButton(button, false) }
        ) { isPressed in
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isPressed ? 0.84 : 0.98), Color.white.opacity(isPressed ? 0.72 : 0.90)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                    .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 1).padding(1))
                    .shadow(color: Color.black.opacity(isPressed ? 0.0 : 0.24), radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
                    .overlay(
                        Text(label)
                            .font(.system(size: max(18, buttonDiameter * 0.42), weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.32))
                    )
                    .frame(width: buttonDiameter, height: buttonDiameter)
            }
            .frame(width: touchSize, height: touchSize)
        }
    }
}

private struct GBDPadView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            shellTheme.colorPalette.shellHighlight.color.opacity(0.18),
                            shellTheme.colorPalette.shellAccent.color.opacity(0.14),
                            Color.black.opacity(0.22)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 120
                    )
                )
                .frame(width: 182, height: 182)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(shellTheme.colorPalette.shellStroke.color.opacity(0.9), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(shellTheme.colorPalette.shellAccent.color.opacity(0.18), lineWidth: 1))

            VStack(spacing: 0) {
                gbDPadArm(.up, onButton: onButton)
                HStack(spacing: 0) {
                    gbDPadArm(.left, onButton: onButton)
                    Color.clear
                        .frame(width: 54, height: 54)
                    gbDPadArm(.right, onButton: onButton)
                }
                gbDPadArm(.down, onButton: onButton)
            }
        }
        .frame(width: 182, height: 182)
    }

    private func gbDPadArm(_ direction: NDSDPadDirection, onButton: @escaping (EmulatorButton, Bool) -> Void) -> some View {
        let button: EmulatorButton = switch direction {
        case .up: .dpadUp
        case .down: .dpadDown
        case .left: .dpadLeft
        case .right: .dpadRight
        }

        return NDSPressableControl(onPress: { onButton(button, true) }, onRelease: { onButton(button, false) }) { isPressed in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                shellTheme.colorPalette.controlSurfaceTop.color.opacity(isPressed ? 0.55 : 0.84),
                                shellTheme.colorPalette.controlSurfaceBottom.color.opacity(isPressed ? 0.62 : 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.9), lineWidth: 2))
                    .shadow(color: shellTheme.colorPalette.shellAccent.color.opacity(isPressed ? 0.10 : 0.18), radius: 6, x: 0, y: 2)
                Image(systemName: arrowSymbol(for: direction))
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(shellTheme.colorPalette.controlIcon.color.opacity(0.78))
                    .rotationEffect(arrowRotation(for: direction))
            }
            .frame(
                width: (direction == .left || direction == .right) ? 70 : 54,
                height: (direction == .up || direction == .down) ? 70 : 54
            )
            .offset(
                x: direction == .left ? 8 : (direction == .right ? -8 : 0),
                y: direction == .up ? 8 : (direction == .down ? -8 : 0)
            )
        }
    }

    private func arrowSymbol(for direction: NDSDPadDirection) -> String {
        switch direction {
        case .up: return "triangle.fill"
        case .down: return "triangle.fill"
        case .left: return "triangle.fill"
        case .right: return "triangle.fill"
        }
    }

    private func arrowRotation(for direction: NDSDPadDirection) -> Angle {
        switch direction {
        case .up: return .degrees(0)
        case .right: return .degrees(90)
        case .down: return .degrees(180)
        case .left: return .degrees(270)
        }
    }
}

private struct GBALightDPadView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            shellTheme.colorPalette.shellAccent.color.opacity(0.10),
                            Color.black.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(shellTheme.colorPalette.shellStroke.color.opacity(0.8), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.20), lineWidth: 1))
                .shadow(color: shellTheme.colorPalette.shellShadow.color.opacity(0.5), radius: 8, x: 0, y: 4)
                .frame(width: 182, height: 182)
            VStack(spacing: 0) {
                arm(.up)
                HStack(spacing: 0) {
                    arm(.left)
                    Color.clear
                        .frame(width: 54, height: 54)
                    arm(.right)
                }
                arm(.down)
            }
        }
        .frame(width: 182, height: 182)
    }

    private func arm(_ direction: NDSDPadDirection) -> some View {
        let button: EmulatorButton = switch direction {
        case .up: .dpadUp
        case .down: .dpadDown
        case .left: .dpadLeft
        case .right: .dpadRight
        }

        return NDSPressableControl(onPress: { onButton(button, true) }, onRelease: { onButton(button, false) }) { isPressed in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                shellTheme.colorPalette.controlSurfaceTop.color.opacity(isPressed ? 0.82 : 0.97),
                                shellTheme.colorPalette.controlSurfaceBottom.color.opacity(isPressed ? 0.82 : 0.97)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.95), lineWidth: 2))
                    .shadow(color: shellTheme.colorPalette.shellShadow.color.opacity(0.55), radius: 3, x: 0, y: 2)

                Image(systemName: symbol(for: direction))
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(shellTheme.colorPalette.controlIcon.color.opacity(0.78))
                    .rotationEffect(rotation(for: direction))
            }
            .frame(
                width: (direction == .left || direction == .right) ? 70 : 54,
                height: (direction == .up || direction == .down) ? 70 : 54
            )
            .offset(
                x: direction == .left ? 8 : (direction == .right ? -8 : 0),
                y: direction == .up ? 8 : (direction == .down ? -8 : 0)
            )
        }
    }

    private func symbol(for _: NDSDPadDirection) -> String { "triangle.fill" }

    private func rotation(for direction: NDSDPadDirection) -> Angle {
        switch direction {
        case .up: return .degrees(0)
        case .right: return .degrees(90)
        case .down: return .degrees(180)
        case .left: return .degrees(270)
        }
    }
}

private struct GBAFaceButtonsView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                HStack { Spacer(); button(.a, "A") }
                HStack { button(.b, "B"); Spacer() }
            }
            .frame(width: 170, height: 170)
        }
        .frame(width: 190, height: 190)
    }

    private func button(_ emulatorButton: EmulatorButton, _ label: String) -> some View {
        let glow = shellTheme.colorPalette.faceButtonGlow.color.opacity(emulatorButton == .a ? 0.65 : 0.45)
        return NDSPressableControl(onPress: { onButton(emulatorButton, true) }, onRelease: { onButton(emulatorButton, false) }) { isPressed in
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            (emulatorButton == .a ? shellTheme.colorPalette.faceButtonAStart : shellTheme.colorPalette.faceButtonBStart).color.opacity(isPressed ? 0.78 : 0.95),
                            (emulatorButton == .a ? shellTheme.colorPalette.faceButtonAEnd : shellTheme.colorPalette.faceButtonBEnd).color.opacity(isPressed ? 0.78 : 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.95), lineWidth: 2))
                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1).padding(2))
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [shellTheme.colorPalette.shellHighlight.color.opacity(0.38), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(5)
                )
                .overlay(
                    Text(label)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(shellTheme.colorPalette.faceButtonText.color.opacity(0.9))
                )
                .frame(width: 78, height: 78)
                .shadow(color: .black.opacity(isPressed ? 0.10 : 0.28), radius: isPressed ? 3 : 8, x: 0, y: isPressed ? 1 : 4)
                .shadow(color: shellTheme.controlStyle.glowEnabled ? glow.opacity(isPressed ? 0.45 : 1) : .clear, radius: emulatorButton == .a ? 7 : 9, x: 0, y: 0)
        }
    }
}

private struct GBAShoulderBar: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let label: String
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void

    init(
        label: String,
        width: CGFloat = 110,
        height: CGFloat = 34,
        fontSize: CGFloat = 20,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) {
        self.label = label
        self.width = width
        self.height = height
        self.fontSize = fontSize
        self.onPress = onPress
        self.onRelease = onRelease
    }

    var body: some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            ZStack {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.74 : 0.90),
                                shellTheme.colorPalette.controlSurfaceBottom.color.opacity(isPressed ? 0.70 : 0.86)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule(style: .continuous).stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.95), lineWidth: 2))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(shellTheme.colorPalette.shellHighlight.color.opacity(0.30), lineWidth: 1)
                            .padding(1)
                    )
                    .shadow(color: .black.opacity(isPressed ? 0.08 : 0.22), radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(shellTheme.controlStyle.shoulderRecessOpacity), Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .padding(2)
                    )
                Text(label)
                    .font(.system(size: fontSize, weight: .light))
                    .foregroundColor(shellTheme.colorPalette.controlIcon.color.opacity(0.72))
            }
            .frame(width: width, height: height)
        }
    }
}

private struct GBACompactPillControl: View {
    let label: String
    let showHomeGlyph: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.18))

                if showHomeGlyph {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.92), Color.white.opacity(0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "house.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.25))
                        )
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5))
                } else {
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.84 : 0.94))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.purple.opacity(0.16))
                    .overlay(Capsule(style: .continuous).stroke(Color.purple.opacity(0.18), lineWidth: 1))
            )
        }
    }
}

private struct GBFaceButtonsView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [shellTheme.colorPalette.shellHighlight.color.opacity(0.12), shellTheme.colorPalette.shellAccent.color.opacity(0.10), Color.clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 95
                    )
                )
                .frame(width: 190, height: 190)

            VStack(spacing: 22) {
                HStack(spacing: 22) {
                    Spacer(minLength: 0)
                    gbButton(.a, "A")
                }
                HStack(spacing: 22) {
                    gbButton(.b, "B")
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 170, height: 170)
        }
        .frame(width: 190, height: 190)
    }

    private func gbButton(_ button: EmulatorButton, _ label: String) -> some View {
        NDSPressableControl(onPress: { onButton(button, true) }, onRelease: { onButton(button, false) }) { isPressed in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (button == .a ? shellTheme.colorPalette.faceButtonAStart : shellTheme.colorPalette.faceButtonBStart).color.opacity(isPressed ? 0.72 : 0.92),
                            (button == .a ? shellTheme.colorPalette.faceButtonAEnd : shellTheme.colorPalette.faceButtonBEnd).color.opacity(isPressed ? 0.78 : 0.95)
                        ],
                        center: .topLeading,
                        startRadius: 6,
                        endRadius: 46
                    )
                )
                .overlay(Circle().stroke(shellTheme.colorPalette.shellHighlight.color.opacity(0.24), lineWidth: 1.5))
                .overlay(Circle().stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.75), lineWidth: 2))
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1).padding(2))
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [shellTheme.colorPalette.shellHighlight.color.opacity(0.30), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(5)
                )
                .overlay(
                    Text(label)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(shellTheme.colorPalette.faceButtonText.color.opacity(0.96))
                )
                .frame(width: 78, height: 78)
                .shadow(color: shellTheme.controlStyle.glowEnabled ? shellTheme.colorPalette.faceButtonGlow.color.opacity(0.22) : .clear, radius: 10, x: 0, y: 0)
                .shadow(color: .black.opacity(isPressed ? 0.10 : 0.24), radius: isPressed ? 3 : 8, x: 0, y: isPressed ? 1 : 4)
        }
    }
}

private struct GBPillControl: View {
    let label: String
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.red.opacity(0.65))
                Circle()
                    .fill(Color.black.opacity(isPressed ? 0.80 : 0.65))
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.black.opacity(0.9), lineWidth: 1.5))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.red.opacity(0.22))
                    .overlay(Capsule(style: .continuous).stroke(Color.red.opacity(0.22), lineWidth: 1))
            )
        }
    }
}

private struct NDSPillActionButton: View {
    let width: CGFloat
    let icon: String?
    let text: String?
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isPressed ? 0.80 : 0.94))
                .overlay(Capsule().stroke(Color.black.opacity(0.35), lineWidth: 2))
                .frame(width: width, height: 28)
                .overlay {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.30))
                    } else if let text {
                        Text(text)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.30))
                    }
                }
        }
    }
}

private enum ShellSystemButtonTheme {
    case light
    case darkRed
    case translucentRed
    case darkPurple
    case neoGlass

    var fill: Color {
        switch self {
        case .light:
            return Color.white.opacity(0.92)
        case .darkRed:
            return Color.red.opacity(0.18)
        case .translucentRed:
            return Color.red.opacity(0.15)
        case .darkPurple:
            return Color.purple.opacity(0.16)
        case .neoGlass:
            return Color.white.opacity(0.10)
        }
    }

    var stroke: Color {
        switch self {
        case .light:
            return Color.black.opacity(0.20)
        case .darkRed:
            return Color.red.opacity(0.24)
        case .translucentRed:
            return Color.red.opacity(0.20)
        case .darkPurple:
            return Color.purple.opacity(0.20)
        case .neoGlass:
            return Color.white.opacity(0.20)
        }
    }

    var text: Color {
        switch self {
        case .light:
            return Color.black.opacity(0.42)
        case .darkRed:
            return Color.red.opacity(0.62)
        case .translucentRed:
            return Color.red.opacity(0.55)
        case .darkPurple:
            return Color.white.opacity(0.22)
        case .neoGlass:
            return Color.white.opacity(0.70)
        }
    }

    var knobFill: Color {
        switch self {
        case .light:
            return Color.white.opacity(0.96)
        case .darkRed, .translucentRed, .darkPurple:
            return Color.white.opacity(0.92)
        case .neoGlass:
            return Color.white.opacity(0.95)
        }
    }

    var knobStroke: Color {
        switch self {
        case .light:
            return Color.black.opacity(0.55)
        case .darkRed, .translucentRed, .darkPurple:
            return Color.black.opacity(0.65)
        case .neoGlass:
            return Color.black.opacity(0.35)
        }
    }
}

private struct ShellSystemButton: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let theme: ShellSystemButtonTheme
    let label: String
    let icon: String?
    let minWidth: CGFloat
    let controlHeight: CGFloat
    let fontSize: CGFloat
    let knobDiameter: CGFloat
    let horizontalPadding: CGFloat
    let showsKnob: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    init(
        theme: ShellSystemButtonTheme,
        label: String,
        icon: String? = nil,
        minWidth: CGFloat = 64,
        controlHeight: CGFloat = 30,
        fontSize: CGFloat = 8,
        knobDiameter: CGFloat = 22,
        horizontalPadding: CGFloat = 6,
        showsKnob: Bool = true,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void = {}
    ) {
        self.theme = theme
        self.label = label
        self.icon = icon
        self.minWidth = minWidth
        self.controlHeight = controlHeight
        self.fontSize = fontSize
        self.knobDiameter = knobDiameter
        self.horizontalPadding = horizontalPadding
        self.showsKnob = showsKnob
        self.onPress = onPress
        self.onRelease = onRelease
    }

    var body: some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(theme.text.opacity(isPressed ? 0.9 : 1.0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(false)

                if showsKnob {
                    Circle()
                        .fill(theme.knobFill.opacity(isPressed ? 0.80 : 1.0))
                        .frame(width: knobDiameter, height: knobDiameter)
                        .overlay(
                            Group {
                                if let icon {
                                    Image(systemName: icon)
                                        .font(.system(size: max(11.0, knobDiameter * 0.50), weight: .semibold))
                                        .foregroundColor(Color.black.opacity(0.28))
                                }
                            }
                        )
                        .overlay(Circle().stroke(theme.knobStroke, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: minWidth)
            .frame(height: controlHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.fill.opacity(isPressed ? 0.78 : 1.0))
                    .overlay(Capsule(style: .continuous).stroke(theme.stroke, lineWidth: 1))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.10 : 0.18), lineWidth: 1)
                    .padding(1)
            )
            .overlay {
                if theme == .neoGlass && shellTheme.controlStyle.glowEnabled {
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.pink.opacity(isPressed ? 0.35 : 0.55), Color.purple.opacity(isPressed ? 0.30 : 0.50)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                        .blur(radius: 0.2)
                }
            }
            .shadow(
                color: theme == .neoGlass && shellTheme.controlStyle.glowEnabled ? shellTheme.colorPalette.shellAccent.color.opacity(isPressed ? 0.12 : 0.20) : .clear,
                radius: 10,
                x: 0,
                y: 0
            )
            .shadow(color: .black.opacity(isPressed ? 0.06 : 0.16), radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
        }
    }
}

private struct ndsSideRailLabel: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 22, weight: .medium))
            .foregroundColor(Color.black.opacity(0.30))
    }
}

private func ndsSideRail(
    buttonLabel: String,
    topIcon: String,
    bottomIcon: String,
    onPress: @escaping () -> Void,
    onRelease: @escaping () -> Void
) -> some View {
    NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isPressed ? 0.80 : 0.95),
                        Color(white: 0.88).opacity(isPressed ? 0.84 : 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.35), lineWidth: 2))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.32), lineWidth: 1).padding(1))
            .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 2)
            .frame(width: 40)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: topIcon)
                        .font(.system(size: 13, weight: .semibold))
                    Capsule()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 18, height: 1.5)
                    Text(buttonLabel)
                        .font(.system(size: 12, weight: .light))
                    Capsule()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 18, height: 1.5)
                    Image(systemName: bottomIcon)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.black.opacity(0.32))
            )
    }
}

#if DEBUG
struct GamePlayView_Previews: PreviewProvider {
    static var previews: some View {
        GamePlayView(
            game: Game(
                title: "Test Game",
                platform: "GB",
                romPath: "/Users/spiderck/Library/Developer/CoreSimulator/Devices/205720B2-7B9D-4497-85DF-141D615263CE/data/Containers/Data/Application/9B1166B2-0F17-4A9D-8796-27E178D9C170/Documents/ROMs/5ca7ba01642a3b27b0cc0b5349b52792795b62d3ed977e98a09390659af96b7b.gb"
            ),
            onExit: {}
        )
    }
}
#endif
