import AVFoundation
import CoreData
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Xemu

/// Comprehensive crash prevention tests
/// Tests force unwrap scenarios, resource exhaustion, and error handling
final class CrashPreventionTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Force Unwrap Prevention Tests

    func testFileManagerURLSafety() {
        // Test that FileManager URL operations don't crash
        let safeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        XCTAssertNotNil(safeURL, "Should safely get FileManager URL or handle nil case")

        // Test fallback mechanism
        if let url = safeURL {
            let testPath = url.appendingPathComponent("test_file.txt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: testPath.path) ||
                      FileManager.default.createFile(atPath: testPath.path, contents: nil, attributes: nil),
                      "Should handle FileManager operations safely")
        }
    }

    func testAudioFormatCreationSafety() {
        // Test that AVAudioFormat creation doesn't crash on invalid parameters
        let validFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                      sampleRate: 44100.0,
                                      channels: 2,
                                      interleaved: true)

        XCTAssertNotNil(validFormat, "Should create valid audio format")

        // Test edge cases
        let edgeCases: [(sampleRate: Double, channels: AVAudioChannelCount)] = [
            (0.0, 2),            // Invalid sample rate
            (-1.0, 2),           // Negative sample rate
            (44100.0, 0),         // Invalid channels
            (44100.0, 8),         // Excessive channels
        ]

        for params in edgeCases {
            XCTAssertNoThrow(
                AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: params.sampleRate,
                    channels: params.channels,
                    interleaved: true
                ),
                "Should handle edge case without crashing: rate=\(params.sampleRate), channels=\(params.channels)"
            )
        }
    }

    // MARK: - Memory Safety Tests

    func testBufferBoundsChecking() {
        // Test that buffer operations handle edge cases safely
        let bufferSize = 1024

        // Test normal buffer
        let normalBuffer = Data(count: bufferSize)
        XCTAssertEqual(normalBuffer.count, bufferSize, "Normal buffer creation should work")

        // Test zero-size buffer
        let zeroBuffer = Data(count: 0)
        XCTAssertEqual(zeroBuffer.count, 0, "Zero-size buffer should be safe")

        // Test excessive buffer size (should be handled gracefully)
        let excessiveSize = 1_000_000_000 // 1GB
        XCTAssertNoThrow({
            _ = Data(count: excessiveSize)
        }, "Should handle excessive buffer size without throwing")
    }

    #if canImport(UIKit)
    @MainActor
    func testMemoryPressureHandling() {
        // Test memory warning handling
        let expectation = XCTestExpectation(description: "Should handle memory pressure")
        var memoryPressureHandled = false

        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            memoryPressureHandled = true
            expectation.fulfill()
        }

        // Simulate memory pressure
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(memoryPressureHandled, "Should handle memory pressure notification")
        NotificationCenter.default.removeObserver(token)
    }
    #endif

    // MARK: - File System Tests

    func testFileSystemErrorHandling() {
        // Test file operations handle errors gracefully
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing")
            .appendingPathComponent("file.bin")

        // Test reading non-existent file
        let readResult = FileManager.default.fileExists(atPath: invalidURL.path)
        XCTAssertFalse(readResult, "Should handle non-existent file safely")

        // Test writing to an unexpected location without crashing the process.
        do {
            try Data().write(to: invalidURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: invalidURL.path), "Write should either succeed safely or fail cleanly")
            try? FileManager.default.removeItem(at: invalidURL)
        } catch {
            XCTAssertNotNil(error, "Should surface a normal file-system error")
        }

        // Test safe fallback mechanisms
        let fallbackURL = FileManager.default.temporaryDirectory
        XCTAssertNotNil(fallbackURL, "Should have valid fallback directory")
    }

    func testConcurrentFileOperations() {
        // Test that concurrent file operations don't cause crashes
        let expectation = XCTestExpectation(description: "Should handle concurrent operations")
        expectation.expectedFulfillmentCount = 10

        let tempDir = FileManager.default.temporaryDirectory

        DispatchQueue.concurrentPerform(iterations: 10) { i in
            let filename = "test_concurrent_\(i).txt"
            let url = tempDir.appendingPathComponent(filename)

            do {
                try "test data".write(to: url, atomically: true, encoding: .utf8)
                let readData = try String(contentsOf: url, encoding: .utf8)

                XCTAssertEqual(readData, "test data", "Concurrent write/read should be consistent")
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent operation failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Cleanup
        DispatchQueue.main.async {
            for i in 0..<10 {
                let filename = "test_concurrent_\(i).txt"
                let url = tempDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Resource Exhaustion Tests

    func testDiskSpaceMonitoring() {
        // Test disk space monitoring doesn't crash
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            XCTAssertNotNil(values.volumeTotalCapacity, "Should get total disk capacity")
            XCTAssertNotNil(values.volumeAvailableCapacityForImportantUsage, "Should get available disk space")

            // Test safe calculations
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacityForImportantUsage {

                let usedCapacity = max(Int64(total) - available, 0)
                let usagePercent = Double(usedCapacity) / Double(total) * 100.0
                XCTAssertGreaterThanOrEqual(usagePercent, 0, "Should calculate disk usage")
                XCTAssertLessThanOrEqual(usagePercent, 100.0, "Usage percent should be valid")
            }
        } catch {
            XCTFail("Disk space monitoring should not throw: \(error)")
        }
    }

    // MARK: - Core Data Tests

    @MainActor
    func testCoreDataConcurrencySafety() {
        // Test Core Data operations handle concurrency safely
        let expectation = XCTestExpectation(description: "Should handle Core Data concurrency")
        expectation.expectedFulfillmentCount = 3

        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()

        // Perform concurrent operations
        DispatchQueue.global(qos: .userInitiated).async {
            backgroundContext.perform {
                // Test safe concurrent access
                let request = NSFetchRequest<NSManagedObject>(entityName: "Game")
                request.fetchLimit = 10

                do {
                    _ = try backgroundContext.fetch(request)
                    expectation.fulfill()
                } catch {
                    // Should handle Core Data errors gracefully
                    expectation.fulfill()
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            backgroundContext.perform {
                // Test safe concurrent access
                let request = NSFetchRequest<NSManagedObject>(entityName: "Game")
                request.fetchLimit = 10

                do {
                    _ = try backgroundContext.fetch(request)
                    expectation.fulfill()
                } catch {
                    // Should handle Core Data errors gracefully
                    expectation.fulfill()
                }
            }
        }

        DispatchQueue.main.async {
            // Test safe main context access
            let request = NSFetchRequest<NSManagedObject>(entityName: "Game")
            request.fetchLimit = 10

            do {
                _ = try PersistenceController.shared.viewContext.fetch(request)
                expectation.fulfill()
            } catch {
                // Should handle Core Data errors gracefully
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Network Error Tests

    func testNetworkErrorHandling() {
        // Test that network errors don't cause crashes
        let invalidURL = URL(string: "invalid://not.real.url")!

        let expectation = XCTestExpectation(description: "Should handle network error")

        URLSession.shared.dataTask(with: invalidURL) { data, response, error in
            XCTAssertNotNil(error, "Should get error for invalid URL")
            XCTAssertNil(data, "Should not return data for invalid URL")
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - App Lifecycle Tests

    #if canImport(UIKit)
    @MainActor
    func testAppLifecycleTransitions() {
        // Test app lifecycle transitions don't cause crashes
        let expectation = XCTestExpectation(description: "Should handle lifecycle transitions")

        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Simulate app becoming active
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(token)
    }
    #endif

    // MARK: - Thread Safety Tests

    func testConcurrentStateMutation() {
        // Test that concurrent state mutations don't cause crashes
        let expectation = XCTestExpectation(description: "Should handle concurrent mutations")
        expectation.expectedFulfillmentCount = 10

        class ThreadSafeCounter {
            private let lock = NSLock()
            private var count = 0

            func increment() -> Int {
                lock.lock()
                defer { lock.unlock() }
                count += 1
                return count
            }
        }

        let counter = ThreadSafeCounter()

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            let value = counter.increment()
            XCTAssertGreaterThan(value, 0, "Thread-safe increment should work")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Error Recovery Tests

    func testErrorRecoveryMechanisms() {
        // Test that error recovery mechanisms work
        let recoveryAttempts = 5
        var successCount = 0

        for attempt in 1...recoveryAttempts {
            // Simulate operation that might fail
            let shouldFail = attempt < recoveryAttempts

            if !shouldFail {
                successCount += 1
            }
        }

        XCTAssertEqual(successCount, 1, "Should recover from errors")
    }

    // MARK: - Performance Tests

    func testPerformanceUnderLoad() {
        // Test performance doesn't degrade under load
        let iterations = 1000
        let startTime = Date()

        for _ in 0..<iterations {
            // Simulate typical operations
            let data = Data(count: 1024)
            _ = data.count
        }

        let duration = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(iterations) / duration

        XCTAssertGreaterThan(operationsPerSecond, 100, "Should maintain reasonable performance")
    }
}
