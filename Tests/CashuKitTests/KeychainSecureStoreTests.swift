import Testing
@testable import CashuKit
import CoreCashu
import Foundation

@Suite("Keychain Secure Store")
struct KeychainSecureStoreTests {
    
    // Create a test-specific keychain store to avoid conflicts
    private let testStore = KeychainSecureStore(
        accessGroup: nil,
        synchronizable: false
    )
    
    // MARK: - Mnemonic Operations
    
    @Test
    func saveMnemonicAndRetrieve() async throws {
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        
        // Save mnemonic
        try await testStore.saveMnemonic(testMnemonic)
        
        // Load mnemonic
        let loaded = try await testStore.loadMnemonic()
        #expect(loaded == testMnemonic)
        
        // Clean up
        try await testStore.deleteMnemonic()
        
        // Verify deletion
        let afterDelete = try await testStore.loadMnemonic()
        #expect(afterDelete == nil)
    }
    
    @Test
    func mnemonicOverwrite() async throws {
        let firstMnemonic = "first test mnemonic phrase"
        let secondMnemonic = "second test mnemonic phrase"
        
        // Save first
        try await testStore.saveMnemonic(firstMnemonic)
        
        // Overwrite with second
        try await testStore.saveMnemonic(secondMnemonic)
        
        // Should get second
        let loaded = try await testStore.loadMnemonic()
        #expect(loaded == secondMnemonic)
        
        // Clean up
        try await testStore.deleteMnemonic()
    }
    
    // MARK: - Seed Operations
    
    @Test
    func saveSeedAndRetrieve() async throws {
        let testSeed = "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678"
        
        // Save seed
        try await testStore.saveSeed(testSeed)
        
        // Load seed
        let loaded = try await testStore.loadSeed()
        #expect(loaded == testSeed)
        
        // Clean up
        try await testStore.deleteSeed()
        
        // Verify deletion
        let afterDelete = try await testStore.loadSeed()
        #expect(afterDelete == nil)
    }
    
    // MARK: - Access Token Operations
    
    @Test
    func saveAccessTokenForMint() async throws {
        let mintURL = URL(string: "https://mint.example.com")!
        let testToken = "test-access-token-12345"
        
        // Save token
        try await testStore.saveAccessToken(testToken, mintURL: mintURL)
        
        // Load token
        let loaded = try await testStore.loadAccessToken(mintURL: mintURL)
        #expect(loaded == testToken)
        
        // Clean up
        try await testStore.deleteAccessToken(mintURL: mintURL)
        
        // Verify deletion
        let afterDelete = try await testStore.loadAccessToken(mintURL: mintURL)
        #expect(afterDelete == nil)
    }
    
    @Test
    func multipleMintsAccessTokens() async throws {
        let mint1 = URL(string: "https://mint1.example.com")!
        let mint2 = URL(string: "https://mint2.example.com")!
        let token1 = "token-for-mint-1"
        let token2 = "token-for-mint-2"
        
        // Save tokens for different mints
        try await testStore.saveAccessToken(token1, mintURL: mint1)
        try await testStore.saveAccessToken(token2, mintURL: mint2)
        
        // Load and verify each token
        let loaded1 = try await testStore.loadAccessToken(mintURL: mint1)
        let loaded2 = try await testStore.loadAccessToken(mintURL: mint2)
        
        #expect(loaded1 == token1)
        #expect(loaded2 == token2)
        
        // Clean up
        try await testStore.deleteAccessToken(mintURL: mint1)
        try await testStore.deleteAccessToken(mintURL: mint2)
    }
    
    // MARK: - Access Token List Operations
    
    @Test
    func saveAccessTokenList() async throws {
        let mintURL = URL(string: "https://mint.example.com")!
        let tokens = ["token1", "token2", "token3"]
        
        // Save token list
        try await testStore.saveAccessTokenList(tokens, mintURL: mintURL)
        
        // Load token list
        let loaded = try await testStore.loadAccessTokenList(mintURL: mintURL)
        #expect(loaded == tokens)
        
        // Clean up
        try await testStore.deleteAccessTokenList(mintURL: mintURL)
        
        // Verify deletion
        let afterDelete = try await testStore.loadAccessTokenList(mintURL: mintURL)
        #expect(afterDelete == nil)
    }
    
    // MARK: - Utility Operations
    
    @Test
    func hasStoredData() async throws {
        // Initially should have no data
        let initialState = try await testStore.hasStoredData()
        #expect(initialState == false)
        
        // Add mnemonic
        try await testStore.saveMnemonic("test mnemonic")
        let withMnemonic = try await testStore.hasStoredData()
        #expect(withMnemonic == true)
        
        // Clean up
        try await testStore.deleteMnemonic()
        
        // Add seed
        try await testStore.saveSeed("test seed")
        let withSeed = try await testStore.hasStoredData()
        #expect(withSeed == true)
        
        // Clean up
        try await testStore.deleteSeed()
        
        // Should be empty again
        let finalState = try await testStore.hasStoredData()
        #expect(finalState == false)
    }
    
    @Test
    func clearAll() async throws {
        // Add some data
        try await testStore.saveMnemonic("test mnemonic")
        try await testStore.saveSeed("test seed")
        
        // Clear all
        try await testStore.clearAll()
        
        // Verify everything is cleared
        let mnemonic = try await testStore.loadMnemonic()
        let seed = try await testStore.loadSeed()
        
        #expect(mnemonic == nil)
        #expect(seed == nil)
        
        let hasData = try await testStore.hasStoredData()
        #expect(hasData == false)
    }
    
    // MARK: - Edge Cases
    
    @Test
    func loadNonExistentItems() async throws {
        // All should return nil for non-existent items
        let mnemonic = try await testStore.loadMnemonic()
        let seed = try await testStore.loadSeed()
        let token = try await testStore.loadAccessToken(mintURL: URL(string: "https://nonexistent.com")!)
        let tokenList = try await testStore.loadAccessTokenList(mintURL: URL(string: "https://nonexistent.com")!)
        
        #expect(mnemonic == nil)
        #expect(seed == nil)
        #expect(token == nil)
        #expect(tokenList == nil)
    }
    
    @Test
    func deleteNonExistentItems() async throws {
        // Should not throw when deleting non-existent items
        try await testStore.deleteMnemonic()
        try await testStore.deleteSeed()
        try await testStore.deleteAccessToken(mintURL: URL(string: "https://nonexistent.com")!)
        try await testStore.deleteAccessTokenList(mintURL: URL(string: "https://nonexistent.com")!)
        
        // Test passes if no errors thrown
        #expect(true)
    }
    
    // MARK: - Convenience Factory Methods
    
    @Test
    func convenienceFactories() async throws {
        // Test default factory
        let defaultStore = KeychainSecureStore.default
        #expect(defaultStore != nil)
        
        // Test shared factory
        let sharedStore = KeychainSecureStore.shared(accessGroup: "com.test.group")
        #expect(sharedStore != nil)
        
        // Test synced factory
        let syncedStore = KeychainSecureStore.synced
        #expect(syncedStore != nil)
    }
}
