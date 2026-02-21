// GamePlayView.swift
// Full-screen emulator view for game playback

import SwiftUI

struct GamePlayView: View {
    let game: Game
    let onExit: () -> Void
    
    @StateObject private var viewModel = GamePlayViewModel()
    @State private var showPauseMenu = false
    @State private var fastForwardSpeed: Int = 1
    @State private var startTask: Task<Void, Never>?
    
    init(game: Game, onExit: @escaping () -> Void) {
        self.game = game
        self.onExit = onExit
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
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
                        
                        // Game display area with Metal rendering
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Status bar
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
                        .padding()
                        .background(Color.black.opacity(0.7))
                    }
                    .frame(height: geometry.size.height * 0.5)
                    .clipped()
                    
                    // Bottom half: Virtual Pad for touch controls
                    VirtualPadView(
                        platform: game.gamePlatform ?? .GB,
                        onButtonPress: { button, isPressed in
                            viewModel.handleButtonPress(button, pressed: isPressed)
                        }
                    )
                    .frame(height: geometry.size.height * 0.5)
                    .clipped()
                }
                
                // Pause menu overlay
                if showPauseMenu {
                    pauseMenuOverlay
                }
            }
        }
        .onAppear {
            startTask?.cancel()
            startTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                if let romPath = game.romPath, let platform = game.gamePlatform {
                    viewModel.startEmulation(romPath: romPath, platform: platform)
                }
            }
        }
        .onDisappear {
            startTask?.cancel()
            startTask = nil
            viewModel.stopEmulation()
        }
    }
    
    private var pauseMenuOverlay: some View {
        Color.black.opacity(0.8)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    Text("Game Paused")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        viewModel.resumeEmulation()
                        showPauseMenu = false
                    }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: { 
                        viewModel.quickSave()
                        showPauseMenu = false
                    }) {
                        Label("Quick Save", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Button(action: { 
                        viewModel.quickLoad()
                        showPauseMenu = false
                    }) {
                        Label("Quick Load", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    
                    HStack(spacing: 12) {
                        ForEach([2, 3, 6], id: \.self) { speed in
                            Button(action: {
                                fastForwardSpeed = fastForwardSpeed == speed ? 1 : speed
                                viewModel.setFastForward(fastForwardSpeed)
                            }) {
                                Text("\(speed)x")
                                    .frame(width: 60, height: 44)
                                    .background(fastForwardSpeed == speed ? Color.orange : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Button(action: { 
                        startTask?.cancel()
                        startTask = nil
                        viewModel.stopEmulation()
                        onExit()
                    }) {
                        Label("Exit to Library", systemImage: "xmark")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
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
