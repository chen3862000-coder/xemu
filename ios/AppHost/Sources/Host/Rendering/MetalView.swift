import SwiftUI
import MetalKit

#if os(iOS)
import UIKit

public struct MetalView: UIViewRepresentable {
    
    private let metalRenderer: MetalRenderer
    private let tick: (() -> Void)?
    private let renderScaleProvider: (() -> Double)?
    
    public init(
        metalRenderer: MetalRenderer,
        tick: (() -> Void)? = nil,
        renderScale: (() -> Double)? = nil
    ) {
        self.metalRenderer = metalRenderer
        self.tick = tick
        self.renderScaleProvider = renderScale
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(metalRenderer: metalRenderer, tick: tick, renderScaleProvider: renderScaleProvider)
    }
    
    @MainActor
    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = metalRenderer.device
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.tick = tick
        context.coordinator.renderScaleProvider = renderScaleProvider
    }
    
    public static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        coordinator.tick = nil
        uiView.isPaused = true
        uiView.enableSetNeedsDisplay = true
        uiView.delegate = nil
    }
    
    @MainActor
    public class Coordinator: NSObject, MTKViewDelegate {
        private let metalRenderer: MetalRenderer
        var tick: (() -> Void)?
        var renderScaleProvider: (() -> Double)?
        private var frameCount = 0
        private var lastDrawableSize: CGSize = .zero
        
        init(
            metalRenderer: MetalRenderer,
            tick: (() -> Void)?,
            renderScaleProvider: (() -> Double)?
        ) {
            self.metalRenderer = metalRenderer
            self.tick = tick
            self.renderScaleProvider = renderScaleProvider
            super.init()
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            applyDrawableScaleIfNeeded(in: view)
        }
        
        public func draw(in view: MTKView) {
            // Wrap in autoreleasepool to prevent memory accumulation
            autoreleasepool {
                _drawInternal(in: view)
            }
        }
        
        private func _drawInternal(in view: MTKView) {
            frameCount += 1
            
            // Call tick first to process frame
            tick?()
            applyDrawableScaleIfNeeded(in: view)
            
            // Defensive: Check view is valid
            guard view.bounds.width > 0 && view.bounds.height > 0 else {
                return
            }
            
            // Defensive: Check device is still valid
            guard view.device != nil else {
                return
            }
            
            guard let drawable = view.currentDrawable else { 
                return 
            }
            
            // Defensive: Validate drawable texture
            guard drawable.texture.width > 0 && drawable.texture.height > 0 else {
                return
            }
            
            metalRenderer.render(to: drawable)
        }

        private func applyDrawableScaleIfNeeded(in view: MTKView) {
            let scale = max(0.5, min(1.0, renderScaleProvider?() ?? 1.0))
            let nativeScale = view.window?.screen.scale ?? UIScreen.main.scale
            let targetSize = CGSize(
                width: max(1, floor(view.bounds.width * nativeScale * scale)),
                height: max(1, floor(view.bounds.height * nativeScale * scale))
            )
            guard targetSize != lastDrawableSize else { return }
            lastDrawableSize = targetSize
            view.drawableSize = targetSize
        }
    }
}

#elseif os(macOS)
import AppKit

public struct MetalView: NSViewRepresentable {
    
    private let metalRenderer: MetalRenderer
    private let tick: (() -> Void)?
    private let renderScaleProvider: (() -> Double)?
    
    public init(
        metalRenderer: MetalRenderer,
        tick: (() -> Void)? = nil,
        renderScale: (() -> Double)? = nil
    ) {
        self.metalRenderer = metalRenderer
        self.tick = tick
        self.renderScaleProvider = renderScale
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(metalRenderer: metalRenderer, tick: tick, renderScaleProvider: renderScaleProvider)
    }
    
    @MainActor
    public func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = metalRenderer.metalDevice
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        
        mtkView.delegate = context.coordinator
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.tick = tick
        context.coordinator.renderScaleProvider = renderScaleProvider
    }
    
    public static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        coordinator.tick = nil
        nsView.isPaused = true
        nsView.enableSetNeedsDisplay = true
        nsView.delegate = nil
    }
    
    @MainActor
    public class Coordinator: NSObject, MTKViewDelegate {
        private let metalRenderer: MetalRenderer
        var tick: (() -> Void)?
        var renderScaleProvider: (() -> Double)?
        private var lastDrawableSize: CGSize = .zero
        
        init(
            metalRenderer: MetalRenderer,
            tick: (() -> Void)?,
            renderScaleProvider: (() -> Double)?
        ) {
            self.metalRenderer = metalRenderer
            self.tick = tick
            self.renderScaleProvider = renderScaleProvider
            super.init()
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            applyDrawableScaleIfNeeded(in: view)
        }
        
        public func draw(in view: MTKView) {
            // Wrap in autoreleasepool to prevent memory accumulation
            autoreleasepool {
                _drawInternal(in: view)
            }
        }
        
        private func _drawInternal(in view: MTKView) {
            // Call tick first to process frame
            tick?()
            applyDrawableScaleIfNeeded(in: view)
            
            // Defensive: Check view is valid
            guard view.bounds.width > 0 && view.bounds.height > 0 else {
                return
            }
            
            // Defensive: Check device is still valid
            guard view.device != nil else {
                return
            }
            
            guard let drawable = view.currentDrawable else { 
                return 
            }
            
            // Defensive: Validate drawable texture
            guard drawable.texture.width > 0 && drawable.texture.height > 0 else {
                return
            }
            
            metalRenderer.render(to: drawable)
        }

        private func applyDrawableScaleIfNeeded(in view: MTKView) {
            let scale = max(0.5, min(1.0, renderScaleProvider?() ?? 1.0))
            let nativeScale = view.window?.backingScaleFactor
                ?? NSScreen.main?.backingScaleFactor
                ?? 1.0
            let targetSize = CGSize(
                width: max(1, floor(view.bounds.width * nativeScale * scale)),
                height: max(1, floor(view.bounds.height * nativeScale * scale))
            )
            guard targetSize != lastDrawableSize else { return }
            lastDrawableSize = targetSize
            view.drawableSize = targetSize
        }
    }
}
#endif
