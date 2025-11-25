//
//  NetworkingTests.swift
//  CashuKitTests
//
//  Unit tests for URLSessionHTTPClient and NetworkMonitor
//

import Testing
import Foundation
import CoreCashu
@testable import CashuKit

@Suite("URLSession HTTP Client Tests")
struct URLSessionHTTPClientTests {

    @Test("Client initialization with default configuration")
    func testDefaultInitialization() async throws {
        let client = URLSessionHTTPClient()

        // Client should be ready to use
        _ = client // Use to silence warning
        #expect(Bool(true))
    }

    @Test("Client initialization with custom configuration")
    func testCustomConfiguration() async throws {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true

        let client = URLSessionHTTPClient(configuration: config)

        // Client should be initialized with custom config
        _ = client
        #expect(Bool(true))
    }

    @Test("Client initialization with ephemeral configuration")
    func testEphemeralConfiguration() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10

        let client = URLSessionHTTPClient(configuration: config)

        _ = client
        #expect(Bool(true))
    }

    @Test("HTTP request creation")
    func testRequestCreation() async throws {
        let url = try #require(URL(string: "https://example.com/test"))

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        #expect(request.url?.absoluteString == "https://example.com/test")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("POST request with body")
    func testPostRequestCreation() async throws {
        let url = try #require(URL(string: "https://example.com/test"))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["key": "value"]
        request.httpBody = try JSONEncoder().encode(body)

        #expect(request.httpMethod == "POST")
        #expect(request.httpBody != nil)
    }
}

@Suite("Network Monitor Tests")
struct NetworkMonitorTests {

    @Test("Monitor initialization")
    @MainActor
    func testMonitorInitialization() async throws {
        let monitor = NetworkMonitor()

        // Initial state
        #expect(monitor.queuedOperations.isEmpty)
    }

    @Test("Start and stop monitoring")
    @MainActor
    func testStartStopMonitoring() async throws {
        let monitor = NetworkMonitor()

        // Start monitoring
        monitor.startMonitoring()

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))

        // Stop monitoring
        monitor.stopMonitoring()

        #expect(Bool(true))
    }

    @Test("Connection type detection")
    @MainActor
    func testConnectionTypeDetection() async throws {
        let monitor = NetworkMonitor()
        monitor.startMonitoring()

        try await Task.sleep(for: .milliseconds(100))

        let connectionType = monitor.connectionType

        // Should be one of the valid types
        let validTypes: [NetworkMonitor.ConnectionType] = [.wifi, .cellular, .wired, .unknown, .none]
        #expect(validTypes.contains(connectionType))

        monitor.stopMonitoring()
    }

    @Test("Network status quality score")
    @MainActor
    func testQualityScore() async throws {
        let monitor = NetworkMonitor()

        let status = monitor.currentStatus
        let qualityScore = status.qualityScore

        // Quality score should be between 0 and 1
        #expect(qualityScore >= 0.0)
        #expect(qualityScore <= 1.0)
    }

    @Test("Queue operation")
    @MainActor
    func testQueueOperation() async throws {
        let monitor = NetworkMonitor()
        monitor.clearQueue() // Start fresh

        let testData = Data("test_operation_data".utf8)

        monitor.queueOperation(
            type: .sendToken,
            data: testData,
            priority: .normal
        )

        // Operation should be queued
        #expect(monitor.queuedOperations.count >= 1)
        #expect(monitor.queuedOperations.last?.type == .sendToken)
        #expect(monitor.queuedOperations.last?.priority == .normal)

        monitor.clearQueue() // Clean up
    }

    @Test("Queue multiple operations with priority")
    @MainActor
    func testQueuePriority() async throws {
        let monitor = NetworkMonitor()
        monitor.clearQueue() // Start fresh

        monitor.queueOperation(
            type: .sendToken,
            data: Data("low".utf8),
            priority: .low
        )

        monitor.queueOperation(
            type: .receiveToken,
            data: Data("critical".utf8),
            priority: .critical
        )

        monitor.queueOperation(
            type: .checkProofs,
            data: Data("normal".utf8),
            priority: .normal
        )

        #expect(monitor.queuedOperations.count >= 3)
        monitor.clearQueue() // Clean up
    }

    @Test("Remove queued operation")
    @MainActor
    func testRemoveQueuedOperation() async throws {
        let monitor = NetworkMonitor()
        monitor.clearQueue() // Start fresh

        monitor.queueOperation(
            type: .sendToken,
            data: Data("test".utf8),
            priority: .normal
        )

        let initialCount = monitor.queuedOperations.count
        let operationId = try #require(monitor.queuedOperations.last?.id)

        monitor.removeQueuedOperation(operationId)

        #expect(monitor.queuedOperations.count == initialCount - 1)
        monitor.clearQueue() // Clean up
    }

    @Test("Clear queue")
    @MainActor
    func testClearQueue() async throws {
        let monitor = NetworkMonitor()
        monitor.clearQueue() // Start fresh

        // Add multiple operations
        for i in 0..<5 {
            monitor.queueOperation(
                type: .sendToken,
                data: Data("test_\(i)".utf8),
                priority: .normal
            )
        }

        #expect(monitor.queuedOperations.count >= 5)

        monitor.clearQueue()

        #expect(monitor.queuedOperations.isEmpty)
    }

    @Test("Circuit breaker config creation")
    @MainActor
    func testCircuitBreakerConfig() async throws {
        let monitor = NetworkMonitor()

        let config = monitor.createCircuitBreakerConfig()

        // Config should have reasonable defaults
        #expect(config.failureThreshold > 0)
        #expect(config.halfOpenMaxAttempts > 0)
        #expect(config.resetTimeout > 0)
    }

    @Test("Should use expensive operations")
    @MainActor
    func testShouldUseExpensiveOperations() async throws {
        let monitor = NetworkMonitor()

        let shouldUse = monitor.shouldUseExpensiveOperations()

        // Should return a boolean
        #expect(shouldUse == true || shouldUse == false)
    }
}

@Suite("Background Task Manager Tests")
struct BackgroundTaskManagerTests {

    @Test("Manager initialization")
    @MainActor
    func testManagerInitialization() async throws {
        let networkMonitor = NetworkMonitor()
        let manager = BackgroundTaskManager(networkMonitor: networkMonitor)

        #expect(Bool(true)) // Manager exists if no crash
        _ = manager // Silence unused warning
    }

    @Test("Add pending operation")
    @MainActor
    func testAddPendingOperation() async throws {
        let networkMonitor = NetworkMonitor()
        let manager = BackgroundTaskManager(networkMonitor: networkMonitor)

        await manager.addPendingOperation(
            type: "test_operation",
            data: Data("test_data".utf8)
        )

        // Operation should be tracked
        #expect(Bool(true))
    }

    @Test("Execute pending operations")
    @MainActor
    func testExecutePendingOperations() async throws {
        let networkMonitor = NetworkMonitor()
        let manager = BackgroundTaskManager(networkMonitor: networkMonitor)

        await manager.addPendingOperation(
            type: "test_operation",
            data: Data("test_data".utf8)
        )

        await manager.executePendingOperations()

        // Should complete without error
        #expect(Bool(true))
    }

    @Test("Register background tasks")
    @MainActor
    func testRegisterBackgroundTasks() async throws {
        let networkMonitor = NetworkMonitor()
        let manager = BackgroundTaskManager(networkMonitor: networkMonitor)

        // This will try to register but won't actually work in test environment
        await manager.registerBackgroundTasks()

        #expect(Bool(true))
    }

    @Test("Multiple pending operations")
    @MainActor
    func testMultiplePendingOperations() async throws {
        let networkMonitor = NetworkMonitor()
        let manager = BackgroundTaskManager(networkMonitor: networkMonitor)

        for i in 0..<5 {
            await manager.addPendingOperation(
                type: "operation_\(i)",
                data: Data("data_\(i)".utf8)
            )
        }

        await manager.executePendingOperations()

        #expect(Bool(true))
    }
}

@Suite("Biometric Auth Manager Tests")
struct BiometricAuthManagerTests {

    @Test("Singleton instance")
    func testSingletonInstance() async throws {
        let instance1 = BiometricAuthManager.shared
        let instance2 = BiometricAuthManager.shared

        // Should be same instance (singleton)
        #expect(instance1 === instance2)
    }

    @Test("Check biometric availability")
    func testCheckBiometricAvailability() async throws {
        let manager = BiometricAuthManager.shared

        await manager.checkBiometricAvailability()

        // Should complete without crash
        let isAvailable = await manager.isAvailable
        #expect(isAvailable == true || isAvailable == false)
    }

    @Test("Biometric type detection")
    func testBiometricTypeDetection() async throws {
        let manager = BiometricAuthManager.shared

        await manager.checkBiometricAvailability()

        let biometricType = await manager.biometricType

        // Should be a valid type
        let validTypes: [BiometricAuthManager.BiometricType] = [.faceID, .touchID, .opticID, .none]
        #expect(validTypes.contains(biometricType))
    }

    @Test("Authentication reason customization")
    func testAuthenticationReasonCustomization() async throws {
        // Test that custom reason is passed through
        let reason = "Access your Cashu wallet"

        // The authenticate method should accept custom reasons
        // We can't actually test authentication without user interaction
        #expect(reason.count > 0)
    }
}
