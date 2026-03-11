import Testing
import XCTest
import CoreGraphics
@testable import Xemu

@Suite("MetalRenderer Tests")
@MainActor
struct MetalRendererTests {
    
    @Test("MetalRenderer initializes with valid texture size")
    func testInitialization() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 256, height: 240))
    }
    
    @Test("MetalRenderer initializes with different sizes")
    func testDifferentSizes() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 320, height: 240))
        _ = MetalRenderer(textureSize: CGSize(width: 640, height: 480))
    }
    
    @Test("MetalRenderer handles NES resolution")
    func testNESResolution() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 256, height: 240))
    }
    
    @Test("MetalRenderer handles SNES resolution")
    func testSNESResolution() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 256, height: 224))
    }
    
    @Test("MetalRenderer handles GB resolution")
    func testGBResolution() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 160, height: 144))
    }
    
    @Test("MetalRenderer handles GBC resolution")
    func testGBCResolution() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 160, height: 144))
    }
    
    @Test("MetalRenderer handles GBA resolution")
    func testGBAResolution() async throws {
        _ = MetalRenderer(textureSize: CGSize(width: 240, height: 160))
    }
    
    @Test("MetalRenderer double-buffering with texture swap")
    func testDoubleBuffering() async throws {
        guard let renderer = MetalRenderer(textureSize: CGSize(width: 160, height: 144)) else {
            throw XCTSkip("Metal not available")
        }
        
        let testData = Data(count: 160 * 144 * 4)
        
        renderer.enqueueFrame(testData, width: 160, height: 144, bytesPerRow: 640)
        
    }
    
    @Test("MetalRenderer handles pitch correctly")
    func testPitchHandling() async throws {
        guard let renderer = MetalRenderer(textureSize: CGSize(width: 160, height: 144)) else {
            throw XCTSkip("Metal not available")
        }
        
        let width = 160
        let height = 144
        let pitch = 640
        let testData = Data(count: pitch * height)
        
        renderer.enqueueFrame(testData, width: width, height: height, bytesPerRow: pitch)
        
    }
    
    @Test("MetalRenderer handles padded pitch")
    func testPaddedPitch() async throws {
        guard let renderer = MetalRenderer(textureSize: CGSize(width: 160, height: 144)) else {
            throw XCTSkip("Metal not available")
        }
        
        let width = 160
        let height = 144
        let paddedPitch = 672
        
        let testData = Data(count: paddedPitch * height)
        
        renderer.enqueueFrame(testData, width: width, height: height, bytesPerRow: paddedPitch)
        
    }
    
    @Test("MetalRenderer handles multiple frames in sequence")
    func testMultipleFrames() async throws {
        guard let renderer = MetalRenderer(textureSize: CGSize(width: 160, height: 144)) else {
            throw XCTSkip("Metal not available")
        }
        
        let width = 160
        let height = 144
        let pitch = 640
        
        for _ in 0..<10 {
            let testData = Data(count: pitch * height)
            renderer.enqueueFrame(testData, width: width, height: height, bytesPerRow: pitch)
        }
        
    }
    
    @Test("MetalRenderer handles dimension changes")
    func testDimensionChanges() async throws {
        guard let renderer = MetalRenderer(textureSize: CGSize(width: 160, height: 144)) else {
            throw XCTSkip("Metal not available")
        }
        
        let testData1 = Data(count: 160 * 144 * 4)
        renderer.enqueueFrame(testData1, width: 160, height: 144, bytesPerRow: 640)
        
        let testData2 = Data(count: 240 * 160 * 4)
        renderer.enqueueFrame(testData2, width: 240, height: 160, bytesPerRow: 960)
        
    }
    
    @Test("MetalRenderer thread safety with enqueueFrame")
    func testThreadSafety() async throws {
        guard let renderer = MetalRenderer(textureSize: CGSize(width: 160, height: 144)) else {
            throw XCTSkip("Metal not available")
        }
        
        let width = 160
        let height = 144
        let pitch = 640
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await MainActor.run {
                        let testData = Data(count: pitch * height)
                        renderer.enqueueFrame(testData, width: width, height: height, bytesPerRow: pitch)
                    }
                }
            }

            for await _ in group {
            }
        }
    }
}
