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
    
    @Test("Keychain basic initialization")
    func testKeychainInit() {
        // Test basic initialization
        let store1 = KeychainSecureStore()
        #expect(type(of: store1) == KeychainSecureStore.self)
        
        // Test with access group
        let store2 = KeychainSecureStore(accessGroup: "com.test.group")
        #expect(type(of: store2) == KeychainSecureStore.self)
        
        // Test with synchronizable
        let store3 = KeychainSecureStore(synchronizable: true)
        #expect(type(of: store3) == KeychainSecureStore.self)
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
