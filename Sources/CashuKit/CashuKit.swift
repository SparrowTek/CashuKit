//
//  CashuKit.swift
//  CashuKit
//
//  Main entry point for CashuKit
//  Cashu protocol implementation for Swift
//  https://github.com/cashubtc/nuts
//

import Foundation
import P256K
import CryptoKit

// MARK: - CashuKit Main Entry Point

/// Main CashuKit library entry point
@CashuActor
public struct CashuKit {
    public static func setup(baseURL: String) {
        CashuEnvironment.current.setup(baseURL: baseURL)
    }
}


/// Quick start examples for common Cashu operations
public struct CashuExamples {
    
    /// Example: Generate a random secret
    public static func generateSecret() -> String {
        return CashuKeyUtils.generateRandomSecret()
    }
    
    /// Example: Create a mint keypair
    public static func createMintKeypair() throws -> MintKeypair {
        return try CashuKeyUtils.generateMintKeypair()
    }
    
    /// Example: Execute the complete BDHKE protocol
    public static func runBDHKEProtocol(secret: String? = nil) throws -> (token: UnblindedToken, isValid: Bool) {
        let testSecret = secret ?? CashuKeyUtils.generateRandomSecret()
        return try CashuBDHKEProtocol.executeProtocol(secret: testSecret)
    }
    
    /// Example: Create a CashuToken from an unblinded token
    public static func createToken(
        from unblindedToken: UnblindedToken,
        mintURL: String,
        amount: Int,
        unit: String? = nil,
        memo: String? = nil
    ) -> CashuToken {
        return CashuTokenUtils.createToken(
            from: unblindedToken,
            mintURL: mintURL,
            amount: amount,
            unit: unit,
            memo: memo
        )
    }
    
    /// Example: Serialize a token to JSON
    public static func serializeToken(_ token: CashuToken) throws -> String {
        return try CashuTokenUtils.serializeToken(token)
    }
    
    /// Example: Deserialize a token from JSON
    public static func deserializeToken(_ jsonString: String) throws -> CashuToken {
        return try CashuTokenUtils.deserializeToken(jsonString)
    }
    
    /// Example: Get mint information
    public static func getMintInfo(from mintURL: String) async throws -> MintInfo {
        let mintService = await MintService()
        return try await mintService.getMintInfo(from: mintURL)
    }
    
    /// Example: Check if mint is available
    public static func isMintAvailable(_ mintURL: String) async -> Bool {
        let mintService = await MintService()
        return await mintService.isMintAvailable(mintURL)
    }
    
    /// Example: Create mock mint info for testing
    public static func createMockMintInfo() async throws -> MintInfo {
        let keypair = try CashuKeyUtils.generateMintKeypair()
        let pubkey = keypair.publicKey.dataRepresentation.hexString
        let mintService = await MintService()
        return mintService.createMockMintInfo(pubkey: pubkey)
    }
}

// MARK: - Testing and Validation

/// Testing utilities for CashuKit
public struct CashuTesting {
    
    /// Run all available tests
    public static func runAllTests() async throws {
        print("=== Running CashuKit Tests ===\n")
        
        // Test NUT-00 functionality
        try testNUT00()
        
        // Test NUT-01 functionality
        try await testNUT01()
        
        // Test token utilities
        try testTokenUtils()
        
        // Test key utilities
        try testKeyUtils()
        
        print("\n=== All Tests Passed ===")
    }
    
    /// Test NUT-00 BDHKE protocol
    private static func testNUT00() throws {
        print("Testing NUT-00: Blind Diffie-Hellman Key Exchange")
        
        let secret = CashuKeyUtils.generateRandomSecret()
        let (token, isValid) = try CashuBDHKEProtocol.executeProtocol(secret: secret)
        
        guard isValid else {
            throw CashuError.verificationFailed
        }
        
        // Verify token has expected properties
        guard !token.secret.isEmpty && !token.signature.isEmpty else {
            throw CashuError.validationFailed
        }
        
        print("✅ NUT-00 test passed")
    }
    
    /// Test NUT-01 Mint Information
    private static func testNUT01() async throws {
        print("Testing NUT-01: Mint Information")
        
        let mintService = await MintService()
        
        // Test URL validation
        let validURLs = [
            "https://mint.example.com",
            "http://localhost:3338",
            "mint.example.com" // Should be normalized to https://
        ]
        
        let invalidURLs = [
            "",
            "not-a-url",
            "ftp://mint.example.com"
        ]
        
        for url in validURLs {
            guard mintService.validateMintURL(url) || mintService.validateMintURL("https://" + url) else {
                throw CashuError.validationFailed
            }
        }
        
        for url in invalidURLs {
            guard !mintService.validateMintURL(url) else {
                throw CashuError.validationFailed
            }
        }
        
        // Test mock mint info creation and validation
        let keypair = try CashuKeyUtils.generateMintKeypair()
        let pubkey = keypair.publicKey.dataRepresentation.hexString
        
        let mockInfo = mintService.createMockMintInfo(pubkey: pubkey)
        
        guard mintService.validateMintInfo(mockInfo) else {
            throw CashuError.validationFailed
        }
        
        // Test NUT support checking
        guard mockInfo.supportsNUT("NUT-00") else {
            throw CashuError.validationFailed
        }
        
        guard mockInfo.supportsBasicOperations() else {
            throw CashuError.validationFailed
        }
        
        let supportedNUTs = mockInfo.getSupportedNUTs()
        guard supportedNUTs.contains("NUT-00") && supportedNUTs.contains("NUT-01") else {
            throw CashuError.validationFailed
        }
        
        print("✅ NUT-01 test passed")
    }
    
    /// Test token utilities
    private static func testTokenUtils() throws {
        print("Testing Token Utilities")
        
        // Create a test token
        let secret = CashuKeyUtils.generateRandomSecret()
        let (unblindedToken, _) = try CashuBDHKEProtocol.executeProtocol(secret: secret)
        
        let token = CashuTokenUtils.createToken(
            from: unblindedToken,
            mintURL: "https://example.com/mint",
            amount: 1000,
            unit: "sat",
            memo: "Test token"
        )
        
        // Test serialization
        let jsonString = try CashuTokenUtils.serializeToken(token)
        let deserializedToken = try CashuTokenUtils.deserializeToken(jsonString)
        
        // Test validation
        let isValid = CashuTokenUtils.validateToken(deserializedToken)
        
        guard isValid else {
            throw CashuError.validationFailed
        }
        
        print("✅ Token utilities test passed")
    }
    
    /// Test key utilities
    private static func testKeyUtils() throws {
        print("Testing Key Utilities")
        
        // Test secret generation
        let secret = CashuKeyUtils.generateRandomSecret()
        let isValidSecret = try CashuKeyUtils.validateSecret(secret)
        
        guard isValidSecret else {
            throw CashuError.validationFailed
        }
        
        // Test keypair generation
        let keypair = try CashuKeyUtils.generateMintKeypair()
        let privateKeyHex = CashuKeyUtils.privateKeyToHex(keypair.privateKey)
        let restoredKeypair = try CashuKeyUtils.privateKeyFromHex(privateKeyHex)
        
        guard keypair.privateKey.rawRepresentation == restoredKeypair.rawRepresentation else {
            throw CashuError.keyGenerationFailed
        }
        
        print("✅ Key utilities test passed")
    }
} 
