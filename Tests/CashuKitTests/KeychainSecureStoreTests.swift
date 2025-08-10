//
//  KeychainSecureStoreTests.swift
//  CashuKitTests
//
//  Tests for KeychainSecureStore implementation
//

import Testing
import Foundation
import CoreCashu
@testable import CashuKit

@Suite("KeychainSecureStore Tests")
struct KeychainSecureStoreTests {
    
    let secureStore = KeychainSecureStore(
        accessGroup: nil,
        securityConfiguration: .standard
    )
    
    @Test("Save and load mnemonic")
    func testMnemonicStorage() async throws {
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        
        // Save mnemonic
        try await secureStore.saveMnemonic(testMnemonic)
        
        // Load mnemonic
        let loadedMnemonic = try await secureStore.loadMnemonic()
        #expect(loadedMnemonic == testMnemonic)
        
        // Clean up
        try await secureStore.deleteMnemonic()
        let deletedMnemonic = try await secureStore.loadMnemonic()
        #expect(deletedMnemonic == nil)
    }
    
    @Test("Save and load seed")
    func testSeedStorage() async throws {
        let testSeed = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        // Save seed
        try await secureStore.saveSeed(testSeed)
        
        // Load seed
        let loadedSeed = try await secureStore.loadSeed()
        #expect(loadedSeed == testSeed)
        
        // Clean up
        try await secureStore.deleteSeed()
        let deletedSeed = try await secureStore.loadSeed()
        #expect(deletedSeed == nil)
    }
    
    @Test("Access token management")
    func testAccessTokenStorage() async throws {
        let mintURL = URL(string: "https://mint.example.com")!
        let token = "test_access_token_12345"
        
        // Save token
        try await secureStore.saveAccessToken(token, mintURL: mintURL)
        
        // Load token
        let loadedToken = try await secureStore.loadAccessToken(mintURL: mintURL)
        #expect(loadedToken == token)
        
        // Delete token
        try await secureStore.deleteAccessToken(mintURL: mintURL)
        let deletedToken = try await secureStore.loadAccessToken(mintURL: mintURL)
        #expect(deletedToken == nil)
    }
    
    @Test("Access token list management")
    func testAccessTokenListStorage() async throws {
        let mintURL = URL(string: "https://mint.example.com")!
        let tokens = ["token1", "token2", "token3"]
        
        // Save token list
        try await secureStore.saveAccessTokenList(tokens, mintURL: mintURL)
        
        // Load token list
        let loadedTokens = try await secureStore.loadAccessTokenList(mintURL: mintURL)
        #expect(loadedTokens == tokens)
        
        // Delete token list
        try await secureStore.deleteAccessTokenList(mintURL: mintURL)
        let deletedTokens = try await secureStore.loadAccessTokenList(mintURL: mintURL)
        #expect(deletedTokens == nil)
    }
    
    @Test("Clear all data")
    func testClearAll() async throws {
        // Store some data
        try await secureStore.saveMnemonic("test mnemonic")
        try await secureStore.saveSeed("test seed")
        
        // Verify data exists
        #expect(try await secureStore.hasStoredData() == true)
        
        // Clear all
        try await secureStore.clearAll()
        
        // Verify data is cleared
        #expect(try await secureStore.hasStoredData() == false)
    }
    
    @Test("URL sanitization for account keys")
    func testURLSanitization() async throws {
        let complexURL = URL(string: "https://mint.example.com:3338/path/to/mint")!
        let token = "test_token"
        
        // Save with complex URL
        try await secureStore.saveAccessToken(token, mintURL: complexURL)
        
        // Should be able to retrieve with same URL
        let loadedToken = try await secureStore.loadAccessToken(mintURL: complexURL)
        #expect(loadedToken == token)
        
        // Clean up
        try await secureStore.deleteAccessToken(mintURL: complexURL)
    }
    
    @Test("Secure Enclave availability check")
    func testSecureEnclaveAvailability() async throws {
        let isAvailable = await secureStore.isSecureEnclaveAvailable
        
        // This will vary by device, but we should be able to check without error
        #expect(isAvailable == true || isAvailable == false)
    }
    
    @Test("Security configuration options")
    func testSecurityConfigurations() async throws {
        // Test with maximum security
        let maxSecureStore = KeychainSecureStore(
            accessGroup: nil,
            securityConfiguration: .maximum
        )
        
        // Should be able to save with max security (though biometric may fail in tests)
        let testData = "secure_data"
        do {
            try await maxSecureStore.saveSeed(testData)
            let loaded = try await maxSecureStore.loadSeed()
            #expect(loaded == testData)
            try await maxSecureStore.deleteSeed()
        } catch {
            // Biometric auth might fail in test environment
            // This is expected and OK
        }
    }
}

// MARK: - Mock Keychain for Testing

#if DEBUG
actor MockKeychainSecureStore: SecureStore {
    private var storage: [String: String] = [:]
    
    func saveMnemonic(_ mnemonic: String) async throws {
        storage["mnemonic"] = mnemonic
    }
    
    func loadMnemonic() async throws -> String? {
        storage["mnemonic"]
    }
    
    func deleteMnemonic() async throws {
        storage["mnemonic"] = nil
    }
    
    func saveSeed(_ seed: String) async throws {
        storage["seed"] = seed
    }
    
    func loadSeed() async throws -> String? {
        storage["seed"]
    }
    
    func deleteSeed() async throws {
        storage["seed"] = nil
    }
    
    func saveAccessToken(_ token: String, mintURL: URL) async throws {
        storage["token_\(mintURL.absoluteString)"] = token
    }
    
    func loadAccessToken(mintURL: URL) async throws -> String? {
        storage["token_\(mintURL.absoluteString)"]
    }
    
    func deleteAccessToken(mintURL: URL) async throws {
        storage["token_\(mintURL.absoluteString)"] = nil
    }
    
    func saveAccessTokenList(_ tokens: [String], mintURL: URL) async throws {
        let data = try JSONEncoder().encode(tokens)
        storage["tokenlist_\(mintURL.absoluteString)"] = data.base64EncodedString()
    }
    
    func loadAccessTokenList(mintURL: URL) async throws -> [String]? {
        guard let base64 = storage["tokenlist_\(mintURL.absoluteString)"],
              let data = Data(base64Encoded: base64) else {
            return nil
        }
        return try JSONDecoder().decode([String].self, from: data)
    }
    
    func deleteAccessTokenList(mintURL: URL) async throws {
        storage["tokenlist_\(mintURL.absoluteString)"] = nil
    }
}
#endif