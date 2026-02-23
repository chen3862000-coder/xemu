// GamePlayView.swift
// Full-screen emulator view for game playback

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GamePlayView: View {
    let game: Game
    let onExit: () -> Void
    
    @StateObject private var viewModel = GamePlayViewModel()
    @State private var showPauseMenu = false
    @State private var showSaveSlotsPanel = false
    @State private var showLaunchStatePicker = false
    @State private var fastForwardSpeed: Int = 1
    @State private var startTask: Task<Void, Never>?
    @State private var saveSlotSummaries: [SaveStateSlotSummary] = []
    
    init(game: Game, onExit: @escaping () -> Void) {
        self.game = game
        self.onExit = onExit
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if game.gamePlatform == .NDS {
                    ndsConsoleLayout(in: geometry)
                } else if game.gamePlatform == .GB || game.gamePlatform == .GBC {
                    gbConsoleLayout(in: geometry)
                } else if game.gamePlatform == .GBA {
                    gbaConsoleLayout(in: geometry)
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
                        showLaunchStatePicker = !saveSlotSummaries.isEmpty
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
                viewModel.pauseEmulation()
                viewModel.refreshSaveStatesStatus()
                saveSlotSummaries = viewModel.saveSlotSummaries()
            } else {
                showSaveSlotsPanel = false
            }
        }
    }

    @ViewBuilder
    private func gbConsoleLayout(in geometry: GeometryProxy) -> some View {
        if isLandscape(geometry) {
            gbConsoleLayoutLandscape(in: geometry)
        } else {
            let isGBC = game.gamePlatform == .GBC
            let gbScreenScale = (game.gamePlatform == .GBC) ? 0.70 : 0.77
            let gbControlScale: CGFloat = (game.gamePlatform == .GBC) ? 0.88 : 0.92
            let shellWidth = min(geometry.size.width - 18, 430.0)
            let shellHeight = min(geometry.size.height - 20, 900.0)
            let displayFrameWidth = shellWidth - 28
            let displayFrameHeight = min(shellHeight * 0.48, 470)
            let gameWidth = min(displayFrameWidth - 14, displayFrameWidth * gbScreenScale)
            let gameHeight = gameWidth * (144.0 / 160.0)

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
        }
    }

    @ViewBuilder
    private func standardGameLayout(in geometry: GeometryProxy) -> some View {
        if isLandscape(geometry) {
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
        } else {
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
        }
    }

    @ViewBuilder
    private func gbaConsoleLayout(in geometry: GeometryProxy) -> some View {
        if isLandscape(geometry) {
            gbaConsoleLayoutLandscape(in: geometry)
        } else {
            let gbaScreenScale: CGFloat = 0.84
            let gbaControlScale: CGFloat = 0.90
            let shellWidth = min(geometry.size.width - 18, 430.0)
            let shellHeight = min(geometry.size.height - 18, 900.0)
            let displayOuterWidth = shellWidth
            let displayOuterHeight = min(shellHeight * 0.53, 500)
            let screenWidth = min(displayOuterWidth - 24, displayOuterWidth * gbaScreenScale)
            let screenHeight = screenWidth * (160.0 / 240.0)

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
                                    .frame(width: screenWidth - 10, height: 1)
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
        }
    }

    @ViewBuilder
    private func ndsConsoleLayout(in geometry: GeometryProxy) -> some View {
        if isLandscape(geometry) {
            ndsConsoleLayoutLandscapeShell(in: geometry)
                .onAppear {
                    viewModel.setNDSScreenLayout(.sideBySide)
                }
        } else {
            let shellWidth = min(geometry.size.width - 18, 420.0)
            let shellHeight = min(geometry.size.height - 28, 860.0)

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
        }
    }

    private func ndsConsoleLayoutLandscapeShell(in geometry: GeometryProxy) -> some View {
        let safeLeading = geometry.safeAreaInsets.leading
        let safeTrailing = geometry.safeAreaInsets.trailing
        let shellWidth = min(geometry.size.width - safeLeading - safeTrailing - 12, 1180.0)
        let shellHeight = min(geometry.size.height - 12, 600.0)
        let innerWidth = shellWidth - 28
        let sideColumnWidth: CGFloat = 150
        let centerGap: CGFloat = 8
        let displayPanelWidth = max(520, min(900, innerWidth - (sideColumnWidth * 2) - (centerGap * 2)))
        let displayAspect = 512.0 / 192.0
        let displayWidth = min(displayPanelWidth - 8, (shellHeight * 0.70) * displayAspect)
        let displayHeight = displayWidth / displayAspect
        let centerModuleHeight = displayHeight + 48
        let utilityRowWidth = min(displayPanelWidth - 12, displayWidth + 10)
        let dpadScale: CGFloat = 0.64
        let faceScale: CGFloat = 0.64
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
        geometry.size.width > geometry.size.height
    }

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
        let screenAreaWidth = shellWidth - 28
        let screenAreaHeight = min((shellWidth - 28) * 1.62, 500)
        let displayWidth = min(screenAreaWidth * 0.78, screenAreaHeight * (256.0 / 384.0))
        let displayHeight = displayWidth * (384.0 / 256.0)
        let screenHalfHeight = (displayHeight - 10) / 2

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
                    .offset(y: screenHalfHeight / 2 + 5)

                    Spacer(minLength: displayWidth)

                    ndsSideRail(buttonLabel: "R", topIcon: "camera.macro", bottomIcon: "speaker.wave.2.fill") {
                        viewModel.handleButtonPress(.r1, pressed: true)
                    } onRelease: {
                        viewModel.handleButtonPress(.r1, pressed: false)
                    }
                    .frame(height: screenHalfHeight)
                    .offset(y: screenHalfHeight / 2 + 5)
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
        VStack(spacing: 8) {
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
        .offset(y: -10)
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
        .offset(y: -18)
        .zIndex(0)
    }

    private func ndsMiniLayoutButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color.black.opacity(0.45))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .overlay(Capsule(style: .continuous).stroke(Color.black.opacity(0.20), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func gbUtilityIcon(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.92), Color.purple.opacity(0.75)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 24
                            )
                        )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: tint.opacity(0.42), radius: 10, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .scaleEffect(0.98)
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
                            emulatorDisplayView
                                .frame(width: screenWidth, height: screenHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let shellWidth = min(geometry.size.width - safeLeading - safeTrailing - 18, 900.0)
        let shellHeight = min(geometry.size.height - 18, 430.0)
        let innerWidth = shellWidth - 28
        let columnGap: CGFloat = 12
        let dpadSize = 182 * gbaDPadScale
        let faceSize = 190 * gbaFaceScale
        let leftControlMinWidth = max(dpadSize + 8, 170)
        let rightControlMinWidth = max(faceSize + 8, 170)
        let minDisplayPanelWidth: CGFloat = 320
        let maxDisplayPanelWidth: CGFloat = 460
        let maxSideColumnWidth = max(220, (innerWidth - minDisplayPanelWidth - (columnGap * 2)) / 2)
        let sideColumnWidth = min(max(leftControlMinWidth, rightControlMinWidth), maxSideColumnWidth)
        let displayPanelWidth = min(
            maxDisplayPanelWidth,
            max(minDisplayPanelWidth, innerWidth - (sideColumnWidth * 2) - (columnGap * 2))
        )
        let screenWidth = min(displayPanelWidth - 24, displayPanelWidth * gbaScreenScale)
        let screenHeight = min(screenWidth * (160.0 / 240.0), shellHeight * 0.45)
        let centerModuleHeight = (shellHeight * 0.55) + 46

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
                                emulatorDisplayView
                                    .frame(width: screenWidth, height: screenHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .padding(.top, 26)
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: screenWidth - 10, height: 1)
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
            AppColors.background.opacity(0.66)
                .ignoresSafeArea()
                .overlay(.ultraThinMaterial.opacity(0.35))
                .onTapGesture { }

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Game Paused")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(game.title ?? "Current game")
                            .font(.system(size: 12, weight: .medium))
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
                            .frame(width: 34, height: 34)
                            .background(AppColors.surfaceLight.opacity(0.65))
                            .clipShape(Circle())
                    }
                }

                if !viewModel.statusMessage.isEmpty || !viewModel.saveStateDebugLine.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        if !viewModel.saveStateDebugLine.isEmpty {
                            Text(viewModel.saveStateDebugLine)
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textMuted)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppColors.surface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 10) {
                    pauseActionButton(title: "Resume", icon: "play.fill", style: .primary) {
                        viewModel.resumeEmulation()
                        showPauseMenu = false
                    }
                    pauseActionButton(title: "Quick Save", icon: "square.and.arrow.down.fill") {
                        viewModel.quickSave()
                        saveSlotSummaries = viewModel.saveSlotSummaries()
                    }
                    pauseActionButton(title: "Quick Load", icon: "square.and.arrow.up.fill") {
                        viewModel.quickLoad()
                    }
                }

                HStack(spacing: 10) {
                    pauseActionButton(title: showSaveSlotsPanel ? "Hide Slots" : "Save Slots", icon: "tray.full.fill") {
                        saveSlotSummaries = viewModel.saveSlotSummaries()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSaveSlotsPanel.toggle()
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach([2, 3, 6], id: \.self) { speed in
                            Button {
                                fastForwardSpeed = fastForwardSpeed == speed ? 1 : speed
                                viewModel.setFastForward(fastForwardSpeed)
                            } label: {
                                Text("\(speed)x")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(fastForwardSpeed == speed ? .white : AppColors.textPrimary)
                                    .frame(width: 46, height: 34)
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
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(saveSlotSummaries) { summary in
                                    saveSlotCard(summary)
                                }
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxHeight: 320)
                    }
                    .padding(12)
                    .background(AppColors.surface.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.surfaceLight.opacity(0.75), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    .fill(AppColors.surface.opacity(0.9))
                    .overlay(.ultraThinMaterial.opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.surfaceLight.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.18), radius: 30, x: 0, y: 12)
            .padding(.horizontal, 16)
        }
    }

    private var launchStatePickerOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("Resume From Save State?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text("We found previous save states for this game. Choose one to continue or start fresh.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textMuted)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(saveSlotSummaries) { summary in
                            Button {
                                viewModel.loadSlotSummary(summary)
                                showLaunchStatePicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    saveSlotThumbnail(summary)
                                        .frame(width: 92, height: 58)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(summary.displayName == "Quick" ? "Quick Save" : "Slot \(summary.displayName)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColors.textPrimary)
                                        Text(summary.metadata?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "Unknown time")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppColors.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "play.fill")
                                        .foregroundColor(AppColors.primary)
                                }
                                .padding(10)
                                .background(AppColors.surface.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)

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
            .padding(16)
            .frame(maxWidth: 680)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.surface.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.surfaceLight.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.16), radius: 22, x: 0, y: 10)
            .padding(.horizontal, 16)
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
                .frame(maxWidth: .infinity, minHeight: 42)
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

    @ViewBuilder
    private func saveSlotCard(_ summary: SaveStateSlotSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            saveSlotThumbnail(summary)
                .frame(height: 84)

            HStack {
                Text(summary.isQuickSlot ? "Quick" : "Slot \(summary.displayName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(summary.isEmpty ? "Empty" : "Saved")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(summary.isEmpty ? AppColors.textMuted : AppColors.primary)
            }

            Text(summary.metadata?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "No save yet")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)

            HStack(spacing: 8) {
                Button {
                    if summary.isQuickSlot {
                        viewModel.quickSave()
                    } else {
                        viewModel.saveState(slot: summary.slot)
                    }
                    saveSlotSummaries = viewModel.saveSlotSummaries()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.surfaceLight.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.surfaceLight.opacity(0.8), lineWidth: 1))

                Button {
                    viewModel.loadSlotSummary(summary)
                } label: {
                    Label("Load", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.plain)
                .disabled(summary.isEmpty)
                .opacity(summary.isEmpty ? 0.45 : 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.surfaceLight.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.surfaceLight.opacity(0.8), lineWidth: 1))
            }
            .foregroundColor(AppColors.textPrimary)
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
            if let data = summary.screenshotData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
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
                            let y = max(0, min(1, value.location.y / size.height))
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
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            NDSDPadArm(direction: .up, onButton: onButton)
            HStack(spacing: 0) {
                NDSDPadArm(direction: .left, onButton: onButton)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 54, height: 54)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.35), lineWidth: 2))
                NDSDPadArm(direction: .right, onButton: onButton)
            }
            NDSDPadArm(direction: .down, onButton: onButton)
        }
        .frame(width: 180, height: 180)
    }
}

private enum NDSDPadDirection { case up, down, left, right }

private struct NDSDPadArm: View {
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
                    .fill(Color.white.opacity(isPressed ? 0.78 : 0.93))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.35), lineWidth: 2)
                    )
                Capsule()
                    .fill(Color.black.opacity(0.28))
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
                .fill(Color.white.opacity(isPressed ? 0.80 : 0.94))
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 2))
                .overlay(
                    Text(label)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.35))
                )
                .frame(width: 62, height: 62)
        }
    }
}

private struct GBDPadView: View {
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color(red: 0.66, green: 0.33, blue: 0.97).opacity(0.14),
                            Color.black.opacity(0.22)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 120
                    )
                )
                .frame(width: 182, height: 182)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.purple.opacity(0.18), lineWidth: 1))

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
                                Color.white.opacity(isPressed ? 0.48 : 0.78),
                                Color(red: 0.78, green: 0.76, blue: 0.88).opacity(isPressed ? 0.55 : 0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.45), lineWidth: 2))
                    .shadow(color: Color.purple.opacity(isPressed ? 0.10 : 0.18), radius: 6, x: 0, y: 2)
                Image(systemName: arrowSymbol(for: direction))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black.opacity(0.22))
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
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
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
                                Color.white.opacity(isPressed ? 0.76 : 0.93),
                                Color(red: 0.75, green: 0.74, blue: 0.82).opacity(isPressed ? 0.78 : 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.5), lineWidth: 2))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)

                Image(systemName: symbol(for: direction))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.22))
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
        NDSPressableControl(onPress: { onButton(emulatorButton, true) }, onRelease: { onButton(emulatorButton, false) }) { isPressed in
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isPressed ? 0.78 : 0.95),
                            Color(red: 0.78, green: 0.77, blue: 0.86).opacity(isPressed ? 0.78 : 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 2))
                .overlay(
                    Text(label)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.20))
                )
                .frame(width: 78, height: 78)
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
        }
    }
}

private struct GBAShoulderBar: View {
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
                                Color.white.opacity(isPressed ? 0.82 : 0.95),
                                Color(red: 0.78, green: 0.76, blue: 0.86).opacity(isPressed ? 0.82 : 0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule(style: .continuous).stroke(Color.black.opacity(0.65), lineWidth: 2))
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.18))
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
    let onButton: (EmulatorButton, Bool) -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.12), Color.purple.opacity(0.10), Color.clear],
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
                            Color(red: 1.0, green: 0.31, blue: 0.85).opacity(isPressed ? 0.72 : 0.92),
                            Color(red: 0.66, green: 0.33, blue: 0.97).opacity(isPressed ? 0.78 : 0.95)
                        ],
                        center: .topLeading,
                        startRadius: 6,
                        endRadius: 46
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1.5))
                .overlay(Circle().stroke(Color.black.opacity(0.34), lineWidth: 2))
                .overlay(
                    Text(label)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.92))
                )
                .frame(width: 78, height: 78)
                .shadow(color: Color(red: 1.0, green: 0.31, blue: 0.85).opacity(0.35), radius: 12, x: 0, y: 0)
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
                    .font(.system(size: 7, weight: .semibold))
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
                if theme == .neoGlass {
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
                color: theme == .neoGlass ? Color.purple.opacity(isPressed ? 0.12 : 0.20) : .clear,
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
            .fill(Color.white.opacity(isPressed ? 0.84 : 0.94))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.35), lineWidth: 2))
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
