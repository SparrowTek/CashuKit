//
//  TokenUtils.swift
//  CashuKit
//
//  Token serialization and utility functions
//

import Foundation

// MARK: - Token Version Enum

/// Token serialization version
public enum TokenVersion: String, CaseIterable {
    case v3 = "A"
    case v4 = "B"
    
    public var description: String {
        switch self {
        case .v3: return "V3 (JSON base64)"
        case .v4: return "V4 (CBOR binary)"
        }
    }
}

// MARK: - Token Serialization Utilities

/// Utilities for token serialization and deserialization following NUT-00 specification
public struct CashuTokenUtils {
    
    // MARK: - Token Serialization Constants
    
    private static let tokenPrefix = "cashu"
    private static let versionV3: Character = "A"
    private static let versionV4: Character = "B"
    private static let uriScheme = "cashu:"
    
    // MARK: - V3 Token Serialization (Deprecated but supported)
    
    /// Serialize a CashuToken to V3 format (base64-encoded JSON)
    /// Format: cashuA[base64_token_json]
    public static func serializeTokenV3(_ token: CashuToken, includeURI: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(token)
        
        // Base64 URL-safe encoding
        let base64String = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
        let serializedToken = tokenPrefix + String(versionV3) + base64String
        
        return includeURI ? uriScheme + serializedToken : serializedToken
    }
    
    /// Deserialize a V3 token from serialized format
    public static func deserializeTokenV3(_ serializedToken: String) throws -> CashuToken {
        var token = serializedToken
        
        // Remove URI scheme if present
        if token.hasPrefix(uriScheme) {
            token = String(token.dropFirst(uriScheme.count))
        }
        
        // Validate prefix and version
        guard token.hasPrefix(tokenPrefix + String(versionV3)) else {
            throw CashuError.invalidTokenFormat
        }
        
        // Extract base64 part
        let base64Part = String(token.dropFirst(tokenPrefix.count + 1))
        
        // Convert back from URL-safe base64
        var base64String = base64Part
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        // Add padding if needed
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64String) else {
            throw CashuError.deserializationFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CashuToken.self, from: data)
    }
    
    // MARK: - V4 Token Serialization (Space-efficient CBOR format)
    
    /// V4 Token structure with shortened keys
    private struct TokenV4: Codable {
        let m: String // mint URL
        let u: String // unit
        let d: String? // memo (optional)
        let t: [KeysetGroup] // token groups by keyset
        
        struct KeysetGroup: Codable {
            let i: Data // keyset ID (as bytes)
            let p: [ProofV4] // proofs for this keyset
        }
        
        struct ProofV4: Codable {
            let a: Int // amount
            let s: String // secret
            let c: Data // signature (as bytes)
        }
    }
    
    /// Serialize a CashuToken to V4 format (CBOR-encoded)
    /// Format: cashuB[base64_token_cbor]
    /// Note: This is a simplified implementation without full CBOR support
    public static func serializeTokenV4(_ token: CashuToken, includeURI: Bool = false) throws -> String {
        // For now, fall back to V3 format since CBOR isn't implemented
        // TODO: Implement full CBOR serialization
        return try serializeTokenV3(token, includeURI: includeURI)
    }
    
    /// Deserialize a V4 token from serialized format
    public static func deserializeTokenV4(_ serializedToken: String) throws -> CashuToken {
        // For now, fall back to V3 format since CBOR isn't implemented
        // TODO: Implement full CBOR deserialization
        return try deserializeTokenV3(serializedToken)
    }
    
    // MARK: - Generic Token Serialization
    
    /// Serialize a CashuToken (defaults to V3 format)
    public static func serializeToken(_ token: CashuToken, version: TokenVersion = .v3, includeURI: Bool = false) throws -> String {
        switch version {
        case .v3:
            return try serializeTokenV3(token, includeURI: includeURI)
        case .v4:
            return try serializeTokenV4(token, includeURI: includeURI)
        }
    }
    
    /// Deserialize a token from serialized format (auto-detects version)
    public static func deserializeToken(_ serializedToken: String) throws -> CashuToken {
        var token = serializedToken
        
        // Remove URI scheme if present
        if token.hasPrefix(uriScheme) {
            token = String(token.dropFirst(uriScheme.count))
        }
        
        // Detect version
        guard token.hasPrefix(tokenPrefix) && token.count >= tokenPrefix.count + 1 else {
            throw CashuError.invalidTokenFormat
        }
        
        let versionChar = token[token.index(token.startIndex, offsetBy: tokenPrefix.count)]
        
        switch versionChar {
        case versionV3:
            return try deserializeTokenV3(serializedToken)
        case versionV4:
            return try deserializeTokenV4(serializedToken)
        default:
            throw CashuError.invalidTokenFormat
        }
    }
    
    // MARK: - Legacy JSON Serialization
    
    /// Serialize a CashuToken to JSON string (for debugging/logging)
    public static func serializeTokenJSON(_ token: CashuToken) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(token)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CashuError.serializationFailed
        }
        return jsonString
    }
    
    /// Deserialize a CashuToken from JSON string (for debugging/testing)
    public static func deserializeTokenJSON(_ jsonString: String) throws -> CashuToken {
        guard let data = jsonString.data(using: .utf8) else {
            throw CashuError.deserializationFailed
        }
        let decoder = JSONDecoder()
        return try decoder.decode(CashuToken.self, from: data)
    }
    
    /// Create a CashuToken from UnblindedToken and mint information
    public static func createToken(
        from unblindedToken: UnblindedToken,
        mintURL: String,
        amount: Int,
        unit: String? = nil,
        memo: String? = nil
    ) -> CashuToken {
        let proof = Proof(
            amount: amount,
            id: UUID().uuidString,
            secret: unblindedToken.secret,
            C: unblindedToken.signature.hexString
        )
        
        let tokenEntry = TokenEntry(
            mint: mintURL,
            proofs: [proof]
        )
        
        return CashuToken(
            token: [tokenEntry],
            unit: unit,
            memo: memo
        )
    }
    
    /// Extract all proofs from a CashuToken
    public static func extractProofs(from token: CashuToken) -> [Proof] {
        return token.token.flatMap { $0.proofs }
    }
    
    /// Validate token structure
    public static func validateToken(_ token: CashuToken) -> Bool {
        // Check that token has at least one entry
        guard !token.token.isEmpty else { return false }
        
        // Check that each token entry has at least one proof
        for entry in token.token {
            guard !entry.proofs.isEmpty else { return false }
            
            // Validate each proof
            for proof in entry.proofs {
                guard proof.amount > 0,
                      !proof.id.isEmpty,
                      !proof.secret.isEmpty,
                      !proof.C.isEmpty else {
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: - Amount-Specific Key Management

/// Represents a mint's keys organized by amount
public struct MintKeys {
    /// Dictionary mapping amount to keypair
    private var keypairs: [Int: MintKeypair] = [:]
    
    public init() {}
    
    /// Get or create a keypair for a specific amount
    public mutating func getKeypair(for amount: Int) throws -> MintKeypair {
        if let existing = keypairs[amount] {
            return existing
        }
        
        let newKeypair = try MintKeypair()
        keypairs[amount] = newKeypair
        return newKeypair
    }
    
    /// Get all amounts that have keys
    public var amounts: [Int] {
        return Array(keypairs.keys).sorted()
    }
    
    /// Get public keys for all amounts
    public func getPublicKeys() -> [Int: String] {
        var publicKeys: [Int: String] = [:]
        for (amount, keypair) in keypairs {
            publicKeys[amount] = keypair.publicKey.dataRepresentation.hexString
        }
        return publicKeys
    }
    
    /// Verify a proof for a specific amount
    public func verifyProof(_ proof: Proof, for amount: Int) throws -> Bool {
        guard let keypair = keypairs[amount] else {
            throw CashuError.invalidSignature
        }
        
        guard let signatureData = Data(hexString: proof.C) else {
            throw CashuError.invalidHexString
        }
        
        let mint = try Mint(privateKey: keypair.privateKey)
        return try mint.verifyToken(secret: proof.secret, signature: signatureData)
    }
} 