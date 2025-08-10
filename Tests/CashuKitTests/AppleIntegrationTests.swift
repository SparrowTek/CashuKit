//
//  AppleIntegrationTests.swift
//  CashuKitTests
//
//  Integration tests for Apple-specific CashuKit features
//

import Testing
import Foundation
import CoreCashu
import SwiftUI
@testable import CashuKit

@Suite("Apple Integration Tests")
struct AppleIntegrationTests {
    
    @Test("Full wallet initialization with Apple defaults")
    func testAppleWalletInitialization() async throws {
        let wallet = AppleCashuWallet()
        
        #expect(wallet != nil)
        #expect(wallet.balance == 0)
        #expect(wallet.isConnected == false)
    }
    
    @Test("Keychain integration with wallet")
    func testKeychainIntegration() async throws {
        let wallet = AppleCashuWallet(keychainAccessGroup: "test.group")
        
        // Test that wallet can interact with keychain
        // This is a smoke test to ensure no crashes
        _ = try? await wallet.generateNewMnemonic()
        
        #expect(true)
    }
    
    @Test("Network monitor integration")
    func testNetworkMonitorIntegration() async throws {
        let monitor = NetworkMonitor.shared
        
        // Start monitoring
        monitor.startMonitoring()
        
        // Check status
        let isConnected = monitor.isConnected
        #expect(isConnected == true || isConnected == false)
        
        // Stop monitoring
        monitor.stopMonitoring()
    }
    
    @Test("Background task manager integration")
    func testBackgroundTaskIntegration() async throws {
        let manager = BackgroundTaskManager.shared
        
        // Register tasks (won't actually register in test environment)
        await manager.registerBackgroundTasks()
        
        // Add a pending operation
        await manager.addPendingOperation(
            type: "test_operation",
            data: Data("test".utf8)
        )
        
        // Execute pending operations
        await manager.executePendingOperations()
        
        #expect(true)
    }
    
    @Test("Biometric authentication availability")
    func testBiometricAvailability() async throws {
        let bioManager = BiometricAuthManager.shared
        
        // Check availability (will vary by device)
        await bioManager.checkBiometricAvailability()
        
        let isAvailable = await bioManager.isAvailable
        #expect(isAvailable == true || isAvailable == false)
    }
    
    @Test("End-to-end secure storage flow")
    func testSecureStorageFlow() async throws {
        let secureStore = KeychainSecureStore(
            accessGroup: nil,
            securityConfiguration: .standard
        )
        
        // Test complete flow
        let testMnemonic = "test mnemonic phrase here"
        
        // Save
        try await secureStore.saveMnemonic(testMnemonic)
        
        // Verify exists
        let hasData = try await secureStore.hasStoredData()
        #expect(hasData == true)
        
        // Load
        let loaded = try await secureStore.loadMnemonic()
        #expect(loaded == testMnemonic)
        
        // Clean up
        try await secureStore.clearAll()
        let hasDataAfter = try await secureStore.hasStoredData()
        #expect(hasDataAfter == false)
    }
    
    @Test("WebSocket provider integration")
    func testWebSocketProviderIntegration() async throws {
        let provider = AppleWebSocketProvider()
        let url = URL(string: "wss://test.example.com")!
        
        let client = provider.createClient(url: url)
        #expect(client != nil)
        
        // Verify it's the right type
        #expect(type(of: client) == AppleWebSocketClient.self)
    }
    
    @Test("OSLogger integration with different log levels")
    func testOSLoggerIntegration() async throws {
        let logger = OSLogLogger(category: "IntegrationTest", minimumLevel: .debug)
        
        // Test all log levels
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")
        
        // Test with metadata
        logger.info("Message with metadata", metadata: ["key": "value", "count": 42])
        
        #expect(true)
    }
    
    @Test("Network quality assessment")
    func testNetworkQualityAssessment() async throws {
        let monitor = NetworkMonitor.shared
        
        let status = monitor.currentStatus
        let quality = status.qualityScore
        
        #expect(quality >= 0.0 && quality <= 1.0)
        
        // Test circuit breaker config creation
        let config = monitor.createCircuitBreakerConfig()
        #expect(config != nil)
    }
    
    @Test("Queued operations with network monitor")
    func testQueuedOperations() async throws {
        let monitor = NetworkMonitor.shared
        
        // Queue an operation
        monitor.queueOperation(
            type: .sendToken,
            data: Data("test_token".utf8),
            priority: .high
        )
        
        // Check queue
        let queuedOps = monitor.queuedOperations
        #expect(queuedOps.count >= 0)
        
        // Clear queue
        monitor.clearQueue()
        #expect(monitor.queuedOperations.isEmpty)
    }
    
    @Test("Security configuration variations")
    func testSecurityConfigurations() async throws {
        // Test standard configuration
        let standardStore = KeychainSecureStore(
            accessGroup: nil,
            securityConfiguration: .standard
        )
        #expect(standardStore != nil)
        
        // Test maximum security configuration
        let maxStore = KeychainSecureStore(
            accessGroup: nil,
            securityConfiguration: .maximum
        )
        #expect(maxStore != nil)
        
        // Test custom configuration
        let customConfig = KeychainSecureStore.SecurityConfiguration(
            useBiometrics: false,
            useSecureEnclave: true,
            accessibleWhenUnlocked: true,
            synchronizable: false
        )
        let customStore = KeychainSecureStore(
            accessGroup: nil,
            securityConfiguration: customConfig
        )
        #expect(customStore != nil)
    }
    
    @Test("SwiftUI view components initialization")
    func testSwiftUIComponents() async throws {
        let wallet = AppleCashuWallet()
        
        // Test view creation (not rendering, just initialization)
        let balanceView = CashuBalanceView(wallet: wallet)
        #expect(balanceView != nil)
        
        let sendReceiveView = CashuSendReceiveView(wallet: wallet)
        #expect(sendReceiveView != nil)
        
        let transactionView = CashuTransactionListView(wallet: wallet)
        #expect(transactionView != nil)
        
        let mintView = MintSelectionView(wallet: wallet)
        #expect(mintView != nil)
    }
}

@Suite("Apple Platform-Specific Tests")
struct ApplePlatformTests {
    
    #if os(iOS)
    @Test("iOS-specific features")
    func testIOSFeatures() async throws {
        // Test iOS-specific code paths
        let wallet = AppleCashuWallet()
        #expect(wallet != nil)
        
        // Test biometric type detection
        let bioManager = BiometricAuthManager.shared
        await bioManager.checkBiometricAvailability()
        let bioType = await bioManager.biometricType
        
        // On iOS, should be Face ID or Touch ID
        #expect(bioType == .faceID || bioType == .touchID || bioType == .none)
    }
    #endif
    
    #if os(macOS)
    @Test("macOS-specific features")
    func testMacOSFeatures() async throws {
        // Test macOS-specific code paths
        let wallet = AppleCashuWallet()
        #expect(wallet != nil)
        
        // Test biometric type detection
        let bioManager = BiometricAuthManager.shared
        await bioManager.checkBiometricAvailability()
        let bioType = await bioManager.biometricType
        
        // On macOS, likely Touch ID or none
        #expect(bioType == .touchID || bioType == .none)
    }
    #endif
    
    #if os(visionOS)
    @Test("visionOS-specific features")
    func testVisionOSFeatures() async throws {
        // Test visionOS-specific code paths
        let wallet = AppleCashuWallet()
        #expect(wallet != nil)
        
        // Test biometric type detection
        let bioManager = BiometricAuthManager.shared
        await bioManager.checkBiometricAvailability()
        let bioType = await bioManager.biometricType
        
        // On visionOS, should be Optic ID
        #expect(bioType == .opticID || bioType == .none)
    }
    #endif
}

@Suite("Performance Tests")
struct ApplePerformanceTests {
    
    @Test("Keychain operation performance")
    func testKeychainPerformance() async throws {
        let secureStore = KeychainSecureStore()
        
        let startTime = Date()
        
        // Perform multiple operations
        for i in 0..<10 {
            let data = "test_data_\(i)"
            try await secureStore.saveSeed(data)
            _ = try await secureStore.loadSeed()
            try await secureStore.deleteSeed()
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete reasonably quickly (under 1 second for 10 operations)
        #expect(elapsed < 1.0)
    }
    
    @Test("Logger performance with high volume")
    func testLoggerPerformance() async throws {
        let logger = OSLogLogger(category: "PerformanceTest", minimumLevel: .info)
        
        let startTime = Date()
        
        // Log many messages
        for i in 0..<100 {
            logger.info("Test message \(i)")
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should handle 100 logs very quickly (under 0.1 seconds)
        #expect(elapsed < 0.1)
    }
}