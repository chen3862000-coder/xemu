// GamePlayView.swift
// Full-screen emulator view for game playback

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GamePlayView: View {
    let game: Game
    let onExit: () -> Void
    
    @EnvironmentObject private var shellThemeManager: ShellThemeManager
    @Environment(\.emulatorShellTheme) private var shellTheme
    @StateObject private var viewModel = GamePlayViewModel()
    @State private var showPauseMenu = false
    @State private var showSaveSlotsPanel = false
    @State private var showLaunchStatePicker = false
    @State private var pauseSheetMode: PauseSheetMode = .quick
    @State private var fastForwardSpeed: Int = 1
    @State private var startTask: Task<Void, Never>?
    @State private var saveSlotSummaries: [SaveStateSlotSummary] = []
    @AppStorage("resumeLaunchPolicy") private var resumeLaunchPolicyRaw = ResumeLaunchPolicy.autoResumeLatest.rawValue
    
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
            }
        }
        .onAppear {
            startTask?.cancel()
            startTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                if let romPath = game.romPath, let platform = game.gamePlatform {
                    viewModel.startEmulation(
                        romPath: romPath,
                        platform: platform,
                        gameTitle: game.title,
                        romHash: game.romPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                    )
                    if viewModel.isRunning, viewModel.hasSavedStatesForCurrentGame() {
                        saveSlotSummaries = viewModel.saveSlotSummaries().filter { !$0.isEmpty }
                        handleLaunchResumeFlowIfNeeded()
                    }
                }
            }
        }
        .onDisappear {
            startTask?.cancel()
            startTask = nil
            viewModel.stopEmulation()
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

    private var resumeLaunchPolicy: ResumeLaunchPolicy {
        ResumeLaunchPolicy(rawValue: resumeLaunchPolicyRaw) ?? .autoResumeLatest
    }

    private func handleLaunchResumeFlowIfNeeded() {
        guard !saveSlotSummaries.isEmpty else { return }
        switch resumeLaunchPolicy {
        case .autoResumeLatest:
            if let latest = saveSlotSummaries
                .filter({ !$0.isEmpty })
                .sorted(by: { ($0.metadata?.createdAt ?? .distantPast) > ($1.metadata?.createdAt ?? .distantPast) })
                .first {
                viewModel.loadSlotSummary(latest)
            }
            showLaunchStatePicker = false
        case .startFresh:
            showLaunchStatePicker = false
        case .askEveryTime:
            showLaunchStatePicker = true
        }
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
            let gameWidth = safeFrameValue(min(displayFrameWidth - 14, displayFrameWidth * gbScreenScale), fallback: 120)
            let gameHeight = safeFrameValue(gameWidth * (144.0 / 160.0), fallback: 108)

            return AnyView(
            VStack(spacing: 0) {
                HStack {
                    Text(game.title ?? "Game Boy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.94))
                        .lineLimit(1)
                    Spacer()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.9))
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
                                        fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                        viewModel.setFastForward(fastForwardSpeed)
                                    }
                                    gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {}
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

    @ViewBuilder
    private func gbcMinimalConsoleLayoutPortrait(in geometry: GeometryProxy) -> some View {
        let shellWidth = safeFrameValue(max(220, min(geometry.size.width - 20, 430.0)), fallback: 220)
        let shellHeight = safeFrameValue(max(360, min(geometry.size.height - 20, 900.0)), fallback: 360)
        let displayFrameWidth = safeFrameValue(shellWidth - 28, fallback: 180)
        let displayFrameHeight = safeFrameValue(min(shellHeight * 0.44, 410), fallback: 170)
        let gameWidth = safeFrameValue(min(displayFrameWidth - 36, displayFrameWidth * 0.70), fallback: 120)
        let gameHeight = safeFrameValue(gameWidth * (144.0 / 160.0), fallback: 108)
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.90)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.90)

        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Color")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)
                Spacer()
                if pauseSheetMode == .quick, !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.yellow.opacity(0.88))
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
                                fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                viewModel.setFastForward(fastForwardSpeed)
                            }
                            gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {}
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
    }

    @ViewBuilder
    private func gbcMinimalConsoleLayoutLandscape(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let shellWidth = min(geometry.size.width - safeLeading - safeTrailing - 18, 920.0)
        let shellHeight = min(geometry.size.height - 18, 430.0)
        let innerWidth = shellWidth - 28
        let columnGap: CGFloat = 14
        let dpadScale = CGFloat(shellOverride.dpadScaleMultiplier ?? 0.82)
        let faceScale = CGFloat(shellOverride.faceButtonScaleMultiplier ?? 0.82)
        let dpadSize = 182 * dpadScale
        let faceSize = 190 * faceScale
        let sideColumnWidth = max(190, min(220, (innerWidth - 360 - columnGap * 2) / 2))
        let centerWidth = max(340, innerWidth - sideColumnWidth * 2 - columnGap * 2)
        let screenWidth = min(centerWidth - 28, centerWidth * 0.74)
        let screenHeight = min(screenWidth * (144.0 / 160.0), shellHeight * 0.58)
        let centerCardHeight = min(shellHeight * 0.70, 286)

        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Color")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
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
                                fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                viewModel.setFastForward(fastForwardSpeed)
                            }
                            gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {}
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
            let screenWidth = safeFrameValue(min(displayOuterWidth - 24, displayOuterWidth * gbaScreenScale), fallback: 120)
            let screenHeight = safeFrameValue(screenWidth * (160.0 / 240.0), fallback: 80)

            return AnyView(
            VStack(spacing: 0) {
                HStack {
                    Text(game.title ?? "Game Boy Advance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.94))
                        .lineLimit(1)
                    Spacer()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.9))
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
                                    fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                    viewModel.setFastForward(fastForwardSpeed)
                                }
                                gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {}
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)
                Spacer()
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.yellow.opacity(0.9))
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
                            fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                            viewModel.setFastForward(fastForwardSpeed)
                        }
                        gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {}
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
                    .frame(width: screenWidth + 24, height: screenHeight + 24)

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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
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
                                    fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                    viewModel.setFastForward(fastForwardSpeed)
                                }
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {}
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

            return AnyView(
                VStack(spacing: 0) {
                    ndsTopBar
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    ndsConsoleLayoutPortraitShell(width: shellWidth, height: shellHeight)
                        .padding(.bottom, 4)

                    statusBar
                        .padding(.horizontal, 8)
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

                                NDSTouchScreenOverlayView { normalizedX, normalizedY, pressed in
                                    if pressed {
                                        viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                                    } else {
                                        viewModel.clearNDSTouch()
                                    }
                                }
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
                                fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                viewModel.setFastForward(fastForwardSpeed)
                            }
                            gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {}
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

                    HStack(spacing: 8) {
                        ndsMiniLayoutButton(title: "TOP") { viewModel.setNDSScreenLayout(.topOnly) }
                        ndsMiniLayoutButton(title: "STACK") { viewModel.setNDSScreenLayout(.stacked) }
                        ndsMiniLayoutButton(title: "BOT") { viewModel.setNDSScreenLayout(.bottomOnly) }
                    }
                    .offset(y: -2)

                    shellSystemButtonsRow(theme: .neoGlass) {
                        showPauseMenu = true
                    } onSelectPress: { pressed in
                        viewModel.handleButtonPress(.select, pressed: pressed)
                    } onStartPress: { pressed in
                        viewModel.handleButtonPress(.start, pressed: pressed)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
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
                                ndsMinimalScreenCard(
                                    width: screenWidth,
                                    height: screenHeight,
                                    cornerRadius: 18,
                                    shadowRadius: 16,
                                    shadowY: 7,
                                    highlight: .clear
                                ) {
                                    emulatorDisplayView
                                        .frame(width: centerWidth, height: screenHeight)
                                        .offset(x: centerWidth / 4 + 6)
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
                                            .frame(width: centerWidth, height: screenHeight)
                                            .offset(x: -(centerWidth / 4 + 6))

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
                                    fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                    viewModel.setFastForward(fastForwardSpeed)
                                }
                                gbUtilityIcon(systemName: "speaker.wave.2", tint: .white) {}
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

                    HStack(spacing: 8) {
                        ndsMiniLayoutButton(title: "TOP") { viewModel.setNDSScreenLayout(.topOnly) }
                        ndsMiniLayoutButton(title: "STACK") { viewModel.setNDSScreenLayout(.sideBySide) }
                        ndsMiniLayoutButton(title: "BOT") { viewModel.setNDSScreenLayout(.bottomOnly) }
                    }
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

    private func ndsConsoleLayoutLandscapeShell(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let shellWidth = min(geometry.size.width - safeLeading - safeTrailing - 12, 1180.0)
        let shellHeight = min(geometry.size.height - 12, 600.0)
        let innerWidth = shellWidth - 28
        let sideColumnWidth: CGFloat = 140
        let centerGap: CGFloat = 6
        let displayPanelWidth = max(520, min(900, innerWidth - (sideColumnWidth * 2) - (centerGap * 2)))
        let displayAspect = 512.0 / 192.0
        let displayWidth = min(displayPanelWidth - 8, (shellHeight * 0.70) * displayAspect)
        let displayHeight = displayWidth / displayAspect
        let centerModuleHeight = displayHeight + 48
        let utilityRowWidth = min(displayPanelWidth - 12, displayWidth + 10)
        let dpadScale: CGFloat = 0.60
        let faceScale: CGFloat = 0.60
        let dpadSize: CGFloat = 180 * dpadScale
        let faceClusterWidth: CGFloat = 200 * faceScale

        return VStack(spacing: 0) {
            ndsTopBar
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.90)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 22, x: 0, y: 12)

                // Shoulder buttons at top corners like a real handheld.
                VStack {
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
                    .padding(.top, 8)
                    Spacer()
                }

                HStack(spacing: centerGap) {
                    VStack {
                        Spacer(minLength: 0)
                        NDSDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(dpadScale)
                        .frame(width: dpadSize, height: dpadSize)
                        Spacer(minLength: 0)
                        shellLandscapeMenuButton(theme: .light) {
                            showPauseMenu = true
                        }
                        .frame(width: sideColumnWidth - 8, alignment: .leading)
                    }
                    .frame(width: sideColumnWidth, height: centerModuleHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        ZStack {
                            emulatorDisplayView
                                .frame(width: displayWidth, height: displayHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.black.opacity(0.9), lineWidth: 3)
                                )
                                .overlay(alignment: .center) {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.85))
                                        .frame(width: 3, height: displayHeight)
                                }
                                .overlay(alignment: .trailing) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.purple.opacity(0.40), lineWidth: 2)
                                        .frame(width: (displayWidth / 2) - 8, height: displayHeight - 8)
                                        .shadow(color: Color.purple.opacity(0.20), radius: 8, x: 0, y: 0)
                                        .padding(.trailing, 4)
                                }

                            // In side-by-side mode, the right half is the touch screen (lower screen).
                            NDSTouchScreenOverlayView { normalizedX, normalizedY, pressed in
                                if pressed {
                                    viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                                } else {
                                    viewModel.clearNDSTouch()
                                }
                            }
                            .frame(width: displayWidth / 2, height: displayHeight)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        }
                        .frame(width: displayPanelWidth, height: max(displayHeight + 10, shellHeight * 0.52))
                        .background(Color.black.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        HStack(spacing: 10) {
                            gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green) { viewModel.quickSave() }
                            gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange) { viewModel.quickLoad() }
                            gbUtilityIcon(systemName: "forward.fill", tint: .yellow) {
                                fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                viewModel.setFastForward(fastForwardSpeed)
                            }
                            gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {}
                        }
                        .frame(width: utilityRowWidth, height: 46)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(width: displayPanelWidth)
                    .frame(maxHeight: .infinity, alignment: .center)

                    VStack {
                        Spacer(minLength: 0)
                        NDSFaceClusterView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(faceScale)
                        .frame(width: faceClusterWidth, height: 150)
                        Spacer(minLength: 0)
                        shellLandscapeSelectStartRow(theme: .light) { pressed in
                            viewModel.handleButtonPress(.select, pressed: pressed)
                        } onStartPress: { pressed in
                            viewModel.handleButtonPress(.start, pressed: pressed)
                        }
                        .frame(width: sideColumnWidth - 8, alignment: .trailing)
                    }
                    .frame(width: sideColumnWidth, height: centerModuleHeight, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.top, 26)
                .padding(.bottom, 14)
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

    private func ndsConsoleLayoutPortraitShell(width shellWidth: CGFloat, height shellHeight: CGFloat) -> some View {
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

            VStack(spacing: 14) {
                ndsDisplayStack(shellWidth: shellWidth)
                ndsCenterDots
                ndsControlDeck
                ndsBottomMenuStrip
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                Text("NDS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.yellow.opacity(0.92))
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
                            .stroke(Color.black.opacity(0.9), lineWidth: 3)
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
                    .overlay(
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                                .frame(height: screenHalfHeight)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                                .frame(height: screenHalfHeight)
                        }
                        .padding(4)
                    )
                    .overlay(alignment: .center) {
                        ZStack {
                            Rectangle()
                                .fill(Color(white: 0.86))
                                .frame(height: 12)
                            Rectangle()
                                .fill(Color.black.opacity(0.92))
                                .frame(height: 3)
                            HStack(spacing: 18) {
                                Capsule().fill(Color.black.opacity(0.35)).frame(width: 12, height: 2)
                                Capsule().fill(Color.black.opacity(0.35)).frame(width: 12, height: 2)
                            }
                            .offset(y: 4)
                        }
                    }
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
                        NDSTouchScreenOverlayView { normalizedX, normalizedY, pressed in
                            if pressed {
                                viewModel.setNDSTouchNormalized(x: normalizedX, y: normalizedY, pressed: true)
                            } else {
                                viewModel.clearNDSTouch()
                            }
                        }
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

                    ndsSideRail(buttonLabel: "R", topIcon: "camera.macro", bottomIcon: "speaker.wave.2.fill") {
                        viewModel.handleButtonPress(.r1, pressed: true)
                    } onRelease: {
                        viewModel.handleButtonPress(.r1, pressed: false)
                    }
                    .frame(height: screenHalfHeight)
                    .offset(y: screenHalfHeight / 2 + 3)
                }
                .frame(width: displayWidth + 96, height: displayHeight)
            }
            .frame(width: displayWidth + 90, height: displayHeight)
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

    private var ndsControlDeck: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 22) {
                NDSDPadView { button, pressed in
                    viewModel.handleButtonPress(button, pressed: pressed)
                }
                .scaleEffect(0.9)
                .frame(maxWidth: .infinity, alignment: .leading)

                NDSFaceClusterView { button, pressed in
                    viewModel.handleButtonPress(button, pressed: pressed)
                }
                .scaleEffect(0.9)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 170)

            HStack(spacing: 8) {
                ndsMiniLayoutButton(title: "TOP") { viewModel.setNDSScreenLayout(.topOnly) }
                ndsMiniLayoutButton(title: "STACK") { viewModel.setNDSScreenLayout(.stacked) }
                ndsMiniLayoutButton(title: "BOT") { viewModel.setNDSScreenLayout(.bottomOnly) }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 212)
        .offset(y: -16)
        .zIndex(1)
    }

    private var ndsBottomMenuStrip: some View {
        shellSystemButtonsRow(theme: .light) {
            showPauseMenu = true
        } onSelectPress: { pressed in
            viewModel.handleButtonPress(.select, pressed: pressed)
        } onStartPress: { pressed in
            viewModel.handleButtonPress(.start, pressed: pressed)
        }
        .padding(.bottom, 0)
        .offset(y: -24)
        .zIndex(0)
    }

    private func ndsMiniLayoutButton(title: String, action: @escaping () -> Void) -> some View {
        let activeLayout = viewModel.getNDSScreenLayout()
        let isActive = switch title {
        case "TOP": activeLayout == .topOnly
        case "STACK": activeLayout == .stacked
        case "BOT": activeLayout == .bottomOnly
        default: false
        }
        return Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isActive ? shellPalette.systemButtonKnobFill.color : shellPalette.controlIcon.color.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? shellPalette.shellAccent.color.opacity(0.88) : shellPalette.systemButtonKnobFill.color.opacity(0.94))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isActive ? shellPalette.shellAccent.color.opacity(0.45) : shellPalette.systemButtonStroke.color.opacity(0.55), lineWidth: 1)
                        )
                )
                .shadow(color: isActive ? shellPalette.shellAccent.color.opacity(0.24) : .clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func gbUtilityIcon(systemName: String, tint: Color, action: @escaping () -> Void) -> AnyView {
        let utilitySize = safeThemeDimension(shellOverride.utilityButtonSize ?? shellTheme.controlStyle.utilityButtonSize)
        let iconColor = shellPalette.utilityIcon.color
        let strokeColor = shellPalette.utilityStroke.color
        let fillStart = shellPalette.utilityFillStart.color
        let fillEnd = shellPalette.utilityFillEnd.color
        let accentGlow = shellPalette.utilityGlow.color
        let accentStroke = shellPalette.shellAccent.color

        if isGBCMinimalShellTheme {
            return AnyView(
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.88))
                    .frame(width: utilitySize, height: utilitySize)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            )
        } else {
            return AnyView(
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: utilitySize, height: utilitySize)
                    .background(
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
                                    endRadius: max(utilitySize * 0.75, 12)
                                )
                            )
                    )
                    .overlay(Circle().stroke(strokeColor, lineWidth: 1))
                    .overlay(Circle().stroke(tint.opacity(0.12), lineWidth: 0.5))
                    .overlay(Circle().stroke(accentStroke.opacity(0.22), lineWidth: 1))
                    .shadow(color: shellTheme.controlStyle.glowEnabled ? accentGlow : .clear, radius: 10, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .scaleEffect(0.98)
            )
        }
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
            ShellSystemButton(theme: theme, label: "MENU", icon: "house.fill", onPress: onMenu, onRelease: {})
            Spacer(minLength: 0)
        }
        .frame(height: 34)
    }

    private func shellLandscapeSelectStartRow(
        theme: ShellSystemButtonTheme,
        onSelectPress: @escaping (Bool) -> Void,
        onStartPress: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 8) {
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

    @ViewBuilder
    private func gbConsoleLayoutLandscape(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let gbScreenScale = (game.gamePlatform == .GBC) ? 0.66 : 0.74
        let gbDPadScale: CGFloat = (game.gamePlatform == .GBC) ? 0.72 : 0.76
        let gbFaceScale: CGFloat = (game.gamePlatform == .GBC) ? 0.70 : 0.74
        let shellWidth = min(geometry.size.width - safeLeading - safeTrailing - 18, 900.0)
        let shellHeight = min(geometry.size.height - 18, 430.0)
        let innerWidth = shellWidth - 28
        let columnGap: CGFloat = 12
        let dpadSize = 182 * gbDPadScale
        let faceSize = 190 * gbFaceScale
        let leftControlMinWidth = max(dpadSize + 8, 170)
        let rightControlMinWidth = max(faceSize + 8, 170)
        let minDisplayPanelWidth: CGFloat = 320
        let maxDisplayPanelWidth: CGFloat = 430
        let maxSideColumnWidth = max(220, (innerWidth - minDisplayPanelWidth - (columnGap * 2)) / 2)
        let sideColumnWidth = min(max(leftControlMinWidth, rightControlMinWidth), maxSideColumnWidth)
        let leftPanelWidth = min(
            maxDisplayPanelWidth,
            max(minDisplayPanelWidth, innerWidth - (sideColumnWidth * 2) - (columnGap * 2))
        )
        let screenWidth = min(leftPanelWidth - 20, leftPanelWidth * gbScreenScale)
        let screenHeight = min(screenWidth * (144.0 / 160.0), shellHeight * 0.62)
        let centerModuleHeight = (shellHeight * 0.72) + 46

        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

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

                HStack(spacing: columnGap) {
                    VStack {
                        Spacer(minLength: 0)
                        GBDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(gbDPadScale)
                        .frame(width: dpadSize, height: dpadSize)
                        Spacer(minLength: 0)
                        shellLandscapeMenuButton(theme: .neoGlass) {
                            showPauseMenu = true
                        }
                        .frame(width: sideColumnWidth - 4, alignment: .leading)
                    }
                    .frame(width: sideColumnWidth, height: centerModuleHeight)
                    .frame(width: sideColumnWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
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
                                    .padding(.top, 14)
                        }
                        .frame(width: leftPanelWidth, height: shellHeight * 0.72)

                        HStack(spacing: 10) {
                            gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green) { viewModel.quickSave() }
                            gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange) { viewModel.quickLoad() }
                            Spacer()
                            gbUtilityIcon(systemName: "forward.fill", tint: .yellow) {
                                fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                viewModel.setFastForward(fastForwardSpeed)
                            }
                            gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {}
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Color(red: 0.07, green: 0.09, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .frame(width: leftPanelWidth)
                    .frame(maxHeight: .infinity, alignment: .center)

                    VStack {
                        Spacer(minLength: 0)
                        GBFaceButtonsView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(gbFaceScale)
                        .frame(width: faceSize, height: faceSize)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        Spacer(minLength: 0)
                        shellLandscapeSelectStartRow(theme: .neoGlass) { pressed in
                            viewModel.handleButtonPress(.select, pressed: pressed)
                        } onStartPress: { pressed in
                            viewModel.handleButtonPress(.start, pressed: pressed)
                        }
                        .frame(width: sideColumnWidth - 4, alignment: .trailing)
                    }
                    .frame(width: sideColumnWidth, height: centerModuleHeight)
                    .frame(width: sideColumnWidth)
                    .padding(.vertical, 10)
                    .frame(maxHeight: .infinity, alignment: .center)
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
    }

    @ViewBuilder
    private func gbaConsoleLayoutLandscape(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let gbaScreenScale: CGFloat = 0.78
        let gbaDPadScale: CGFloat = 0.72
        let gbaFaceScale: CGFloat = 0.72
        let shellWidth = safeFrameValue(max(520, min(geometry.size.width - safeLeading - safeTrailing - 18, 900.0)), fallback: 520)
        let shellHeight = safeFrameValue(max(260, min(geometry.size.height - 18, 430.0)), fallback: 260)
        let innerWidth = safeFrameValue(shellWidth - 28, fallback: 492)
        let columnGap: CGFloat = 12
        let dpadSize = 182 * gbaDPadScale
        let faceSize = 190 * gbaFaceScale
        let leftControlMinWidth = max(dpadSize + 8, 170)
        let rightControlMinWidth = max(faceSize + 8, 170)
        let minDisplayPanelWidth: CGFloat = 320
        let maxDisplayPanelWidth: CGFloat = 460
        let maxSideColumnWidth = max(180, (innerWidth - minDisplayPanelWidth - (columnGap * 2)) / 2)
        let sideColumnWidth = safeFrameValue(min(max(leftControlMinWidth, rightControlMinWidth), maxSideColumnWidth), fallback: 180)
        let displayPanelWidth = safeFrameValue(min(
            maxDisplayPanelWidth,
            max(minDisplayPanelWidth, innerWidth - (sideColumnWidth * 2) - (columnGap * 2))
        ), fallback: minDisplayPanelWidth)
        let screenWidth = safeFrameValue(min(displayPanelWidth - 24, displayPanelWidth * gbaScreenScale), fallback: 180)
        let screenHeight = safeFrameValue(min(screenWidth * (160.0 / 240.0), shellHeight * 0.45), fallback: 120)
        let centerModuleHeight = safeFrameValue((shellHeight * 0.55) + 46, fallback: 180)

        VStack(spacing: 0) {
            HStack {
                Text(game.title ?? "Game Boy Advance")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
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
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    Spacer()
                }

                HStack(spacing: columnGap) {
                    VStack {
                        Spacer(minLength: 0)
                        GBALightDPadView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(gbaDPadScale)
                        .frame(width: dpadSize, height: dpadSize)
                        Spacer(minLength: 0)
                        shellLandscapeMenuButton(theme: .darkPurple) {
                            showPauseMenu = true
                        }
                        .frame(width: sideColumnWidth - 4, alignment: .leading)
                    }
                    .frame(width: sideColumnWidth, height: centerModuleHeight)
                    .frame(width: sideColumnWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 8) {
                        VStack(spacing: 0) {
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
                                    .padding(.top, 26)
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: safeFrameValue(screenWidth - 10, fallback: 1), height: 1)
                                    .padding(.top, 14)
                            }
                            .frame(width: displayPanelWidth, height: shellHeight * 0.55)

                            HStack(spacing: 12) {
                                gbUtilityIcon(systemName: "square.and.arrow.down.fill", tint: .green) { viewModel.quickSave() }
                                gbUtilityIcon(systemName: "square.and.arrow.up.fill", tint: .orange) { viewModel.quickLoad() }
                                Spacer()
                                gbUtilityIcon(systemName: "forward.fill", tint: .yellow) {
                                    fastForwardSpeed = fastForwardSpeed == 2 ? 1 : 2
                                    viewModel.setFastForward(fastForwardSpeed)
                                }
                                gbUtilityIcon(systemName: "speaker.wave.2.fill", tint: .cyan) {}
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(Color.black.opacity(0.98))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    }
                    .frame(width: displayPanelWidth)
                    .frame(maxHeight: .infinity, alignment: .center)

                    VStack {
                        Spacer(minLength: 0)
                        GBAFaceButtonsView { button, pressed in
                            viewModel.handleButtonPress(button, pressed: pressed)
                        }
                        .scaleEffect(gbaFaceScale)
                        .frame(width: faceSize, height: faceSize)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        Spacer(minLength: 0)
                        shellLandscapeSelectStartRow(theme: .darkPurple) { pressed in
                            viewModel.handleButtonPress(.select, pressed: pressed)
                        } onStartPress: { pressed in
                            viewModel.handleButtonPress(.start, pressed: pressed)
                        }
                        .frame(width: sideColumnWidth - 4, alignment: .trailing)
                    }
                    .frame(width: sideColumnWidth, height: centerModuleHeight)
                    .frame(width: sideColumnWidth)
                    .padding(.vertical, 8)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.top, 28)
                .padding(.bottom, 10)
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

    private var emulatorDisplayView: some View {
        ZStack {
            if let renderer = viewModel.renderer {
                MetalView(metalRenderer: renderer, tick: viewModel.tick)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .overlay(
                        Text("Emulator Display\n(Core: \(viewModel.statusMessage.isEmpty ? "Ready" : viewModel.statusMessage))")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    )
            }
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
                
                Text("FPS: \(viewModel.currentFPS)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
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
    
    private var pauseMenuOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.42)
                .ignoresSafeArea()
                .overlay(.ultraThinMaterial.opacity(0.16))
                .onTapGesture { }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Game Paused")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(game.title ?? "Current game")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        viewModel.resumeEmulation()
                        showPauseMenu = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.surfaceLight.opacity(0.65))
                            .clipShape(Circle())
                    }
                }

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }

                pauseActionButton(title: "Resume", icon: "play.fill", style: .primary) {
                    viewModel.resumeEmulation()
                    showPauseMenu = false
                }

                HStack(spacing: 10) {
                    pauseActionButton(title: "Quick Save", icon: "square.and.arrow.down.fill") {
                        viewModel.quickSave()
                        saveSlotSummaries = viewModel.saveSlotSummaries()
                    }
                    pauseActionButton(title: "Quick Load", icon: "square.and.arrow.up.fill") {
                        viewModel.quickLoad()
                    }
                }

                HStack(spacing: 10) {
                    pauseActionButton(title: pauseSheetMode == .advanced ? "Back" : "More…", icon: pauseSheetMode == .advanced ? "chevron.left" : "ellipsis.circle") {
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
                        ForEach([1, 2, 3, 6], id: \.self) { speed in
                            Button {
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
                            pauseActionButton(title: showSaveSlotsPanel ? "Hide Saves" : "Manage Saves", icon: "tray.full.fill") {
                                saveSlotSummaries = viewModel.saveSlotSummaries()
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showSaveSlotsPanel.toggle()
                                }
                            }
                            pauseActionButton(title: "Controls", icon: "gamecontroller") {
                                // Reserved for future in-game controls editor
                            }
                        }

                        if showSaveSlotsPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Save States")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text("Quick + 10 Slots")
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

                pauseActionButton(title: "Exit to Library", icon: "xmark", style: .destructive) {
                    startTask?.cancel()
                    startTask = nil
                    viewModel.stopEmulation()
                    onExit()
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.surface.opacity(0.95))
                    .overlay(.ultraThinMaterial.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.surfaceLight.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.10), radius: 22, x: 0, y: 10)
            .padding(.horizontal, 16)
        }
    }

    private var launchStatePickerOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.46)
                .ignoresSafeArea()
                .overlay(.ultraThinMaterial.opacity(0.14))
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resume From Save State?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("Choose a save to continue, or start fresh.")
                        .font(.system(size: 14))
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
                    pauseActionButton(title: "Start Fresh", icon: "sparkles") {
                        showLaunchStatePicker = false
                    }
                    pauseActionButton(title: "Open Pause Menu", icon: "line.3.horizontal") {
                        showLaunchStatePicker = false
                        showPauseMenu = true
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 620)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.surface.opacity(0.96))
                    .overlay(.ultraThinMaterial.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.08), radius: 18, x: 0, y: 8)
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
                Text("Unable to Start Game")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(viewModel.statusMessage)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    pauseActionButton(title: "Retry", icon: "arrow.clockwise", style: .primary) {
                        startTask?.cancel()
                        startTask = nil
                        if let romPath = game.romPath, let platform = game.gamePlatform {
                            viewModel.startEmulation(
                                romPath: romPath,
                                platform: platform,
                                gameTitle: game.title,
                                romHash: game.romPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                            )
                            if viewModel.isRunning, viewModel.hasSavedStatesForCurrentGame() {
                                saveSlotSummaries = viewModel.saveSlotSummaries().filter { !$0.isEmpty }
                                handleLaunchResumeFlowIfNeeded()
                            }
                        }
                    }
                    pauseActionButton(title: "Back", icon: "xmark") {
                        onExit()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.surface.opacity(0.96))
                    .overlay(.ultraThinMaterial.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.10), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 18)
        }
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
        case .destructive: return .white
        }
    }

    private func backgroundColor(for style: PauseActionStyle) -> Color {
        switch style {
        case .primary: return AppColors.primary
        case .normal: return AppColors.surfaceLight.opacity(0.55)
        case .destructive: return AppColors.error.opacity(0.85)
        }
    }

    private func borderColor(for style: PauseActionStyle) -> Color {
        switch style {
        case .primary: return AppColors.primary.opacity(0.9)
        case .normal: return AppColors.surfaceLight.opacity(0.8)
        case .destructive: return AppColors.error.opacity(0.9)
        }
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(summary.isQuickSlot ? "Quick Save" : "Slot \(summary.displayName)")
                        .font(.system(size: mode == .launchPicker ? 15 : 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if mode == .pauseMenu {
                        Text(summary.isEmpty ? "Empty" : "Saved")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(summary.isEmpty ? AppColors.textMuted : AppColors.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.surfaceLight.opacity(summary.isEmpty ? 0.35 : 0.55)))
                    } else if isRecommended {
                        Text("Recommended")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.primary.opacity(0.10)))
                    }
                }
                Text(summary.metadata?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "No save yet")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if mode == .launchPicker {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceLight.opacity(0.45))
                    .clipShape(Circle())
            } else {
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
    var yBiasNormalized: CGFloat = 0.035
    @State private var isPressed = false

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let size = proxy.size
                            guard size.width > 0, size.height > 0 else { return }
                            let x = max(0, min(1, value.location.x / size.width))
                            let rawY = value.location.y / size.height
                            let y = max(0, min(1, rawY + yBiasNormalized))
                            isPressed = true
                            onStylus(x, y, true)
                        }
                        .onEnded { _ in
                            if isPressed {
                                isPressed = false
                                onStylus(0, 0, false)
                            }
                        }
                )
                .onDisappear {
                    if isPressed {
                        isPressed = false
                        onStylus(0, 0, false)
                    }
                }
        }
    }
}

private struct NDSPressableControl<Content: View>: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onPress: () -> Void
    let onRelease: () -> Void
    let content: (Bool) -> Content
    @State private var isPressed = false

    init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void, @ViewBuilder content: @escaping (Bool) -> Content) {
        self.onPress = onPress
        self.onRelease = onRelease
        self.content = content
    }

    var body: some View {
        content(isPressed)
            .scaleEffect(isPressed ? shellTheme.controlStyle.pressScale : 1.0)
            .animation(.easeOut(duration: shellTheme.animationStyle.tapDuration), value: isPressed)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onRelease()
                        }
                    }
            )
            .onDisappear {
                if isPressed {
                    isPressed = false
                    onRelease()
                }
            }
    }
}

private struct NDSDPadView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            shellTheme.colorPalette.shellHighlight.color.opacity(shellTheme.controlStyle.dpadBasePlateOpacity),
                            shellTheme.colorPalette.shellAccent.color.opacity(shellTheme.controlStyle.dpadBasePlateOpacity * 0.9),
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.25), lineWidth: 1))
                .shadow(color: shellTheme.colorPalette.shellShadow.color.opacity(0.6), radius: 8, x: 0, y: 4)
                .frame(width: 182, height: 182)

            VStack(spacing: 0) {
                NDSDPadArm(direction: .up, onButton: onButton)
                HStack(spacing: 0) {
                    NDSDPadArm(direction: .left, onButton: onButton)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(shellTheme.colorPalette.controlSurfaceTop.color.opacity(0.95))
                        .frame(width: 54, height: 54)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.8), lineWidth: 2))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(shellTheme.colorPalette.shellHighlight.color.opacity(0.35), lineWidth: 1).padding(1))
                    NDSDPadArm(direction: .right, onButton: onButton)
                }
                NDSDPadArm(direction: .down, onButton: onButton)
            }
        }
        .frame(width: 180, height: 180)
    }
}

private enum NDSDPadDirection { case up, down, left, right }

private struct NDSDPadArm: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let direction: NDSDPadDirection
    let onButton: (EmulatorButton, Bool) -> Void

    private var button: EmulatorButton {
        switch direction {
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        }
    }

    var body: some View {
        NDSPressableControl(
            onPress: { onButton(button, true) },
            onRelease: { onButton(button, false) }
        ) { isPressed in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(shellTheme.colorPalette.controlSurfaceTop.color.opacity(isPressed ? 0.80 : 0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.8), lineWidth: 2)
                    )
                Capsule()
                    .fill(shellTheme.colorPalette.controlIcon.color.opacity(0.85))
                    .frame(
                        width: (direction == .left || direction == .right) ? 28 : 6,
                        height: (direction == .up || direction == .down) ? 28 : 6
                    )
            }
            .frame(
                width: (direction == .left || direction == .right) ? 64 : 54,
                height: (direction == .up || direction == .down) ? 64 : 54
            )
            .offset(
                x: direction == .left ? 6 : (direction == .right ? -6 : 0),
                y: direction == .up ? 6 : (direction == .down ? -6 : 0)
            )
        }
    }
}

private struct NDSFaceClusterView: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        VStack(spacing: 10) {
            round(.x, "X")
            HStack(spacing: 12) {
                round(.y, "Y")
                Color.clear.frame(width: 62, height: 62)
                round(.a, "A")
            }
            round(.b, "B")
        }
        .frame(width: 200, height: 180)
    }

    private func round(_ button: EmulatorButton, _ label: String) -> some View {
        NDSPressableControl(
            onPress: { onButton(button, true) },
            onRelease: { onButton(button, false) }
        ) { isPressed in
            Circle()
                .fill(shellTheme.colorPalette.controlSurfaceTop.color.opacity(isPressed ? 0.84 : 0.96))
                .overlay(Circle().stroke(shellTheme.colorPalette.controlStroke.color.opacity(0.8), lineWidth: 2))
                .overlay(
                    Text(label)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(shellTheme.colorPalette.controlIcon.color.opacity(0.8))
                )
                .frame(width: 62, height: 62)
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
                    .font(.system(size: 20, weight: .bold))
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
                    .font(.system(size: 20, weight: .bold))
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
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
                .shadow(color: shellTheme.controlStyle.glowEnabled ? glow.opacity(isPressed ? 0.45 : 1) : .clear, radius: emulatorButton == .a ? 7 : 9, x: 0, y: 0)
        }
    }
}

private struct GBAShoulderBar: View {
    @Environment(\.emulatorShellTheme) private var shellTheme
    let label: String
    let onPress: () -> Void
    let onRelease: () -> Void

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
                    .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(shellTheme.colorPalette.controlIcon.color.opacity(0.72))
            }
            .frame(width: 110, height: 34)
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
                .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 3)
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
    let onPress: () -> Void
    let onRelease: () -> Void

    init(
        theme: ShellSystemButtonTheme,
        label: String,
        icon: String? = nil,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void = {}
    ) {
        self.theme = theme
        self.label = label
        self.icon = icon
        self.onPress = onPress
        self.onRelease = onRelease
    }

    var body: some View {
        NDSPressableControl(onPress: onPress, onRelease: onRelease) { isPressed in
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(theme.text.opacity(isPressed ? 0.9 : 1.0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Circle()
                    .fill(theme.knobFill.opacity(isPressed ? 0.80 : 1.0))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Group {
                            if let icon {
                                Image(systemName: icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.28))
                            }
                        }
                    )
                    .overlay(Circle().stroke(theme.knobStroke, lineWidth: 1.5))
            }
            .padding(.horizontal, 6)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.fill.opacity(isPressed ? 0.78 : 1.0))
                    .overlay(Capsule(style: .continuous).stroke(theme.stroke, lineWidth: 1))
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
                        .font(.system(size: 12, weight: .bold))
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
