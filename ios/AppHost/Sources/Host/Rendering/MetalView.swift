import SwiftUI
import MetalKit

#if os(iOS)
import UIKit

public struct MetalView: UIViewRepresentable {
    
    private let metalRenderer: MetalRenderer
    private let tick: (() -> Void)?
    
    public init(metalRenderer: MetalRenderer, tick: (() -> Void)? = nil) {
        self.metalRenderer = metalRenderer
        self.tick = tick
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(metalRenderer: metalRenderer, tick: tick)
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
        private var frameCount = 0
        
        init(metalRenderer: MetalRenderer, tick: (() -> Void)?) {
            self.metalRenderer = metalRenderer
            self.tick = tick
            super.init()
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
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
    }
}

#elseif os(macOS)
import AppKit

public struct MetalView: NSViewRepresentable {
    
    private let metalRenderer: MetalRenderer
    private let tick: (() -> Void)?
    
    public init(metalRenderer: MetalRenderer, tick: (() -> Void)? = nil) {
        self.metalRenderer = metalRenderer
        self.tick = tick
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(metalRenderer: metalRenderer, tick: tick)
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
        
        init(metalRenderer: MetalRenderer, tick: (() -> Void)?) {
            self.metalRenderer = metalRenderer
            self.tick = tick
            super.init()
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
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
    }
}
#endif
