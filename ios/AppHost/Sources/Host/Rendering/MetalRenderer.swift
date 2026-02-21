import Foundation
import Metal
import MetalKit

@MainActor
public final class MetalRenderer {
    private struct ColorAdjustments {
        var brightness: Float = 1.0
        var gamma: Float = 1.0
        var contrast: Float = 1.0
        var saturation: Float = 1.0
    }
    
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState?
    private var frameTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    private let textureSize: CGSize
    
    private let dataLock = NSLock()
    private var pendingFrame: (data: Data, width: Int, height: Int, bytesPerRow: Int)?
    private var texW = 0
    private var texH = 0
    
    public init?(textureSize: CGSize) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        self.device = device
        self.textureSize = textureSize
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return nil
        }
        
        self.commandQueue = commandQueue
        
        setupPipeline()
        setupVertexBuffer()
    }
    
    private func setupPipeline() {
        let library: MTLLibrary?
        
        do {
            library = try device.makeLibrary(source: metalShaders, options: nil)
        } catch {
            print("Failed to compile embedded Metal shaders: \(error)")
            if let defaultLibrary = device.makeDefaultLibrary() {
                library = defaultLibrary
            } else {
                print("Failed to create Metal library (no compiled metallib found)")
                return
            }
        }
        
        guard let vertexFunction = library?.makeFunction(name: "vertexShader"),
              let fragmentFunction = library?.makeFunction(name: "fragmentShader") else {
            print("Failed to create shader functions")
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func setupVertexBuffer() {
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,
             1.0, -1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 0.0,
             1.0,  1.0, 1.0, 0.0
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<Float>.size,
                                         options: [])
    }
    
    public func enqueueFrame(_ data: Data, width: Int, height: Int, bytesPerRow: Int) {
        dataLock.lock()
        pendingFrame = (data, width, height, bytesPerRow)
        dataLock.unlock()
    }
    
    private func uploadFrame(_ frame: (data: Data, width: Int, height: Int, bytesPerRow: Int)) {
        autoreleasepool {
            _uploadFrameInternal(frame)
        }
    }
    
    private func _uploadFrameInternal(_ frame: (data: Data, width: Int, height: Int, bytesPerRow: Int)) {
        let width = frame.width
        let height = frame.height
        
        // Defensive: Validate dimensions
        guard width > 0 && height > 0 && frame.bytesPerRow > 0 else {
            print("[MetalRenderer] Invalid dimensions: width=\(width), height=\(height), bytesPerRow=\(frame.bytesPerRow)")
            return
        }
        
        // Debug: Log actual values
        // print("[MetalRenderer] Upload: width=\(width), height=\(height), bytesPerRow=\(frame.bytesPerRow), data.count=\(frame.data.count), needed=\(frame.bytesPerRow * height)")
        
        // Recreate textures if size changed
        if width != texW || height != texH {
            texW = width
            texH = height
            
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            desc.usage = [.shaderRead]
            desc.storageMode = .shared
            
            frameTexture = nil
            frameTexture = device.makeTexture(descriptor: desc)
        }

        guard let tex = frameTexture else { return }
        
        // Validate buffer size
        let needed = frame.bytesPerRow * height
        guard frame.data.count >= needed else {
            // print("[MetalRenderer] SKIP: Buffer too small - got \(frame.data.count), need \(needed) (width=\(width), height=\(height), pitch=\(frame.bytesPerRow))")
            return
        }

        // print("[MetalRenderer] UPLOAD: data=\(frame.data.count), needed=\(needed), w=\(width), h=\(height), pitch=\(frame.bytesPerRow)")
        
        frame.data.withUnsafeBytes { rbp in
            guard let base = rbp.baseAddress else { return }
            tex.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: frame.bytesPerRow
            )
        }

    }
    
    /// Clean up resources when stopping emulation
    public func cleanup() {
        dataLock.lock()
        pendingFrame = nil
        dataLock.unlock()
        
        commandBufferLock.lock()
        lastCommandBuffer = nil
        commandBufferLock.unlock()
        
        frameTexture = nil
        texW = 0
        texH = 0
    }
    
    private var frameCount: Int = 0
    private var colorAdjustments = ColorAdjustments()
    
    private let commandBufferLock = NSLock()
    private var lastCommandBuffer: MTLCommandBuffer?
    
    public func render(to drawable: CAMetalDrawable) {
        // Wrap entire render in autoreleasepool to prevent memory accumulation
        autoreleasepool {
            _renderInternal(to: drawable)
        }
    }

    public func setColorAdjustments(
        brightness: Float = 1.0,
        gamma: Float = 1.0,
        contrast: Float = 1.0,
        saturation: Float = 1.0
    ) {
        colorAdjustments = ColorAdjustments(
            brightness: brightness,
            gamma: gamma,
            contrast: contrast,
            saturation: saturation
        )
    }
    
    private func _renderInternal(to drawable: CAMetalDrawable) {
        frameCount += 1
        
        // Defensive: Validate drawable texture
        let drawableTexture = drawable.texture
        guard drawableTexture.width > 0 && drawableTexture.height > 0 else {
            return
        }
        
        dataLock.lock()
        let frame = pendingFrame
        pendingFrame = nil
        dataLock.unlock()
        
        if let frame {
            uploadFrame(frame)
        }
        
        guard let renderPipelineState = renderPipelineState,
              let tex = frameTexture,
              let vertexBuffer = vertexBuffer else {
            return
        }
        
        // Defensive: Validate texture dimensions
        guard tex.width > 0 && tex.height > 0 else {
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawableTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Defensive: Use optional binding for render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            // Failed to create encoder - commit empty buffer to avoid hanging
            commandBuffer.commit()
            return
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(tex, index: 0)
        var adjustments = colorAdjustments
        renderEncoder.setFragmentBytes(
            &adjustments,
            length: MemoryLayout<ColorAdjustments>.stride,
            index: 1
        )
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        commandBufferLock.lock()
        lastCommandBuffer = commandBuffer
        commandBufferLock.unlock()
    }
    
    public var metalDevice: MTLDevice {
        return device
    }
    
    public func setupWithMTKView(_ mtkView: MTKView) {
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
    }
}

private let metalShaders = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                               device const float4 *vertices [[buffer(0)]]) {
    VertexOut out;
    float4 vert = vertices[vertexID];
    out.position = float4(vert.xy, 0.0, 1.0);
    out.texCoord = vert.zw;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture2d<float> texture [[texture(0)]],
                                constant float4 &adjust [[buffer(1)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 c = texture.sample(s, in.texCoord);

    // BGRA buffer -> RGB output
    float3 color = float3(c.b, c.g, c.r);

    // adjust = (brightness, gamma, contrast, saturation)
    float brightness = adjust.x;
    float gamma = max(adjust.y, 0.01);
    float contrast = adjust.z;
    float saturation = adjust.w;

    // Adaptive black lift: keep GB natural, brighten darker GBC output.
    float blackLift = max((brightness - 1.20) * 0.08, 0.0);
    color = pow(max(color, 0.0), float3(1.0 / gamma));
    color = ((color - 0.5) * contrast) + 0.5;

    float luma = dot(color, float3(0.299, 0.587, 0.114));
    color = mix(float3(luma), color, saturation);
    color = color * brightness + blackLift;
    color = clamp(color, 0.0, 1.0);

    return float4(color, 1.0);
}
"""
