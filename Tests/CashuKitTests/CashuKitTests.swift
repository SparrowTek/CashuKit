//
//  CashuKitTests.swift
//  CashuKitTests
//
//  Basic tests for CashuKit Apple-specific functionality
//

import Testing
import Foundation
@testable import CashuKit

@Suite("CashuKit Basic Tests")
struct CashuKitTests {
    
    @Test("CashuKit imports successfully")
    func testImport() {
        // If this compiles and runs, the import is successful
        #expect(true)
    }
    
    @Test("AppleCashuWallet initialization")
    func testWalletInit() async {
        let wallet = await AppleCashuWallet()
        #expect(await wallet.balance == 0)
        #expect(await wallet.isConnected == false)
    }
    
    @Test("Keychain configuration options")
    func testKeychainConfigs() {
        let standardConfig = KeychainSecureStore.SecurityConfiguration.standard
        #expect(standardConfig.useSecureEnclave == true)
        
        let maxConfig = KeychainSecureStore.SecurityConfiguration.maximum
        #expect(maxConfig.useBiometrics == true)
        #expect(maxConfig.useSecureEnclave == true)
        #expect(maxConfig.accessibleWhenUnlocked == false)
        #expect(maxConfig.synchronizable == false)
    }
    
    @Test("Network monitor instances")
    func testNetworkMonitor() async {
        let monitor1 = await NetworkMonitor()
        let monitor2 = await NetworkMonitor()
        
        // Should be different instances
        #expect(monitor1 !== monitor2)
    }
    
    @Test("Background task manager instances") 
    func testBackgroundTaskManager() async {
        let networkMonitor = await NetworkMonitor()
        let manager1 = BackgroundTaskManager(networkMonitor: networkMonitor)
        let manager2 = BackgroundTaskManager(networkMonitor: networkMonitor)
        
        // Should be different instances
        #expect(manager1 !== manager2)
    }
    
    @Test("Biometric auth manager singleton")
    func testBiometricAuthManager() async {
        let manager1 = BiometricAuthManager.shared
        let manager2 = BiometricAuthManager.shared
        
        // Should be the same instance (singleton)
        #expect(manager1 === manager2)
    }
}