//
//  TokenUtils.swift
//  CashuKit
//
//  Token serialization and utility functions
//

import Foundation

// MARK: - Token Serialization Utilities

/// Utilities for token serialization and deserialization
public struct CashuTokenUtils {
    /// Serialize a CashuToken to JSON string
    public static func serializeToken(_ token: CashuToken) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(token)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CashuError.serializationFailed
        }
        return jsonString
    }
    
    /// Deserialize a CashuToken from JSON string
    public static func deserializeToken(_ jsonString: String) throws -> CashuToken {
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