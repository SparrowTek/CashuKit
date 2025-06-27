//
//  CashuKit.swift
//  CashuKit
//
//  Main entry point for CashuKit
//  Cashu protocol implementation for Swift
//  https://github.com/cashubtc/nuts
//

import Foundation
import K1
import CryptoKit

// MARK: - CashuKit Main Entry Point

/// Main CashuKit library entry point
public struct CashuKit: Sendable {
    
    /// Version of CashuKit
    public static let version = "1.0.0"
    
    /// Supported NUTs versions
    public static let supportedNUTs = [
        "NUT-00": "Blind Diffie-Hellman Key Exchange",
        "NUT-01": "Mint Information",
        "NUT-02": "Mint Key Management",
        "NUT-03": "Mint Key Distribution",
        "NUT-04": "Blinded Messages",
        "NUT-05": "Melt Tokens for Bitcoin",
        "NUT-06": "Spending Conditions",
        "NUT-07": "Proofs",
        "NUT-08": "Blind Signatures",
        "NUT-09": "Blind Signature DLEQ Proofs",
        "NUT-10": "Spending Conditions",
        "NUT-11": "Pay to Pubkey",
        "NUT-12": "DLEQ Proofs",
        "NUT-13": "Deterministic Secrets",
        "NUT-14": "Hashed Timelock Contracts",
        "NUT-15": "Partial Multi-Path Payments",
        "NUT-16": "Animated QR Codes",
        "NUT-17": "WebSocket Subscriptions",
        "NUT-18": "Payment Requests",
        "NUT-19": "Cached Responses",
        "NUT-20": "Signature on Mint Quote",
        "NUT-21": "Clear Authentication",
        "NUT-22": "Blind Authentication",
        "NUT-23": "Payment Method: BOLT11",
        "NUT-24": "HTTP 402 Payment Required"
    ]
    
    /// Initialize CashuKit
    public init() {}
    
    /// Get library information
    public static func getInfo() -> [String: String] {
        return [
            "version": version,
            "description": "Cashu protocol implementation for Swift",
            "repository": "https://github.com/cashubtc/nuts",
            "supported_nuts": "\(supportedNUTs.count) NUTs supported"
        ]
    }
    
    /// Check if a specific NUT is supported
    public static func isNUTSupported(_ nut: String) -> Bool {
        return supportedNUTs.keys.contains(nut)
    }
    
    /// Get description for a specific NUT
    public static func getNUTDescription(_ nut: String) -> String? {
        return supportedNUTs[nut]
    }
}

// MARK: - Convenience Accessors

/// Global access to CashuKit functionality
public let cashuKit = CashuKit()

// MARK: - Quick Start Examples

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
}

// MARK: - Testing and Validation

/// Testing utilities for CashuKit
public struct CashuTesting {
    
    /// Run all available tests
    public static func runAllTests() throws {
        print("=== Running CashuKit Tests ===\n")
        
        // Test NUT-00 functionality
        try testNUT00()
        
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
        
        print("✅ NUT-00 test passed")
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