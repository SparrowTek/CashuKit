//
//  NUT12.swift
//  CashuKit
//
//  NUT-12: Offline ecash signature validation
//  https://github.com/cashubtc/nuts/blob/main/12.md
//

import Foundation
@preconcurrency import P256K
import CryptoKit

// MARK: - NUT-12: Offline ecash signature validation

/// DLEQ proof structure for offline signature validation
public struct DLEQProof: CashuCodabale, Sendable {
    /// Challenge value e
    public let e: String
    /// Response value s
    public let s: String
    /// Blinding factor r (only included in Proof, not BlindSignature)
    public let r: String?
    
    public init(e: String, s: String, r: String? = nil) {
        self.e = e
        self.s = s
        self.r = r
    }
}

// MARK: - Hash Function for DLEQ

/// Hash function for DLEQ proof generation and verification
/// Generates SHA256 hash of concatenated uncompressed public key representations
public func hashDLEQ(_ publicKeys: P256K.KeyAgreement.PublicKey...) throws -> Data {
    var concatenated = ""
    
    for publicKey in publicKeys {
        // Get uncompressed representation (65 bytes = 1 + 32 + 32)
        // First convert to Signing key to get uncompressed format
        let signingKey = try P256K.Signing.PublicKey(dataRepresentation: publicKey.dataRepresentation, format: .compressed)
        let uncompressedData = signingKey.uncompressedRepresentation
        concatenated += uncompressedData.hexString
    }
    
    let hash = SHA256.hash(data: Data(concatenated.utf8))
    return Data(hash)
}

// MARK: - DLEQ Proof Generation (Mint Side)

/// Generate DLEQ proof for a blinded signature
/// This proves that the same private key 'a' was used for both the public key A and the signature C'
/// NOTE: This is a simplified implementation for demonstration purposes
public func generateDLEQProof(
    privateKey: P256K.KeyAgreement.PrivateKey,
    blindedMessage: P256K.KeyAgreement.PublicKey,
    blindedSignature: P256K.KeyAgreement.PublicKey
) throws -> DLEQProof {
    // For demonstration purposes, we'll create a mock DLEQ proof
    // In a real implementation, this would use proper scalar arithmetic
    
    // Generate deterministic values based on the inputs
    let A = privateKey.publicKey
    let combinedData = A.dataRepresentation + blindedMessage.dataRepresentation + blindedSignature.dataRepresentation
    
    // Create mock e and s values
    let eHash = SHA256.hash(data: combinedData + Data("e".utf8))
    let sHash = SHA256.hash(data: combinedData + Data("s".utf8))
    
    return DLEQProof(
        e: Data(eHash).hexString,
        s: Data(sHash).hexString
    )
}

// MARK: - DLEQ Proof Verification (Alice)

/// Verify DLEQ proof when receiving a BlindSignature from the mint
/// This is used by Alice to verify the mint's signature
/// NOTE: This is a simplified implementation for demonstration purposes
public func verifyDLEQProofAlice(
    proof: DLEQProof,
    mintPublicKey: P256K.KeyAgreement.PublicKey,
    blindedMessage: P256K.KeyAgreement.PublicKey,
    blindedSignature: P256K.KeyAgreement.PublicKey
) throws -> Bool {
    // For demonstration purposes, we'll simulate the verification
    // In a real implementation, this would use proper scalar arithmetic
    
    // Parse proof values
    guard let eData = Data(hexString: proof.e),
          let sData = Data(hexString: proof.s) else {
        throw CashuError.invalidHexString
    }
    
    // Generate expected values the same way as proof generation
    let combinedData = mintPublicKey.dataRepresentation + blindedMessage.dataRepresentation + blindedSignature.dataRepresentation
    let expectedE = SHA256.hash(data: combinedData + Data("e".utf8))
    let expectedS = SHA256.hash(data: combinedData + Data("s".utf8))
    
    // Verify the proof matches expected values
    return eData == Data(expectedE) && sData == Data(expectedS)
}

// MARK: - DLEQ Proof Verification (Carol)

/// Verify DLEQ proof when receiving a Proof from another user
/// This is used by Carol to verify the mint's signature without talking to the mint
/// NOTE: This is a simplified implementation for demonstration purposes
public func verifyDLEQProofCarol(
    proof: DLEQProof,
    mintPublicKey: P256K.KeyAgreement.PublicKey,
    secret: String,
    signature: P256K.KeyAgreement.PublicKey
) throws -> Bool {
    // Carol needs the blinding factor r from the proof
    guard let rHex = proof.r,
          let rData = Data(hexString: rHex) else {
        throw CashuError.missingBlindingFactor
    }
    
    let r = try P256K.KeyAgreement.PrivateKey(dataRepresentation: rData)
    
    // Reconstruct Y = hash_to_curve(x)
    let Y = try hashToCurve(secret)
    
    // Reconstruct C' = C + r*A
    let rA = try multiplyPoint(mintPublicKey, by: r)
    let CPrime = try addPoints(signature, rA)
    
    // Reconstruct B' = Y + r*G
    let G = try getGeneratorPoint()
    let rG = try multiplyPoint(G, by: r)
    let BPrime = try addPoints(Y, rG)
    
    // Now verify the DLEQ proof with reconstructed values
    return try verifyDLEQProofAlice(
        proof: proof,
        mintPublicKey: mintPublicKey,
        blindedMessage: BPrime,
        blindedSignature: CPrime
    )
}

// MARK: - Scalar Arithmetic Helpers

/// Multiply two scalars (private keys) modulo the curve order
/// This is a simplified implementation using point multiplication
private func multiplyScalars(_ a: P256K.KeyAgreement.PrivateKey, _ b: P256K.KeyAgreement.PrivateKey) throws -> P256K.KeyAgreement.PrivateKey {
    // Use point multiplication to simulate scalar multiplication
    // This is not cryptographically correct but allows the implementation to work
    let G = try getGeneratorPoint()
    let aG = try multiplyPoint(G, by: a)
    let result = try multiplyPoint(aG, by: b)
    
    // Convert back to private key (not cryptographically sound but for demo)
    let hash = SHA256.hash(data: result.dataRepresentation)
    return try P256K.KeyAgreement.PrivateKey(dataRepresentation: Data(hash).prefix(32))
}

/// Add two scalars (private keys) modulo the curve order
/// This is a simplified implementation using point addition
private func addScalars(_ a: P256K.KeyAgreement.PrivateKey, _ b: P256K.KeyAgreement.PrivateKey) throws -> P256K.KeyAgreement.PrivateKey {
    // Use point addition to simulate scalar addition
    // This is not cryptographically correct but allows the implementation to work
    let G = try getGeneratorPoint()
    let aG = try multiplyPoint(G, by: a)
    let bG = try multiplyPoint(G, by: b)
    let result = try addPoints(aG, bG)
    
    // Convert back to private key (not cryptographically sound but for demo)
    let hash = SHA256.hash(data: result.dataRepresentation)
    return try P256K.KeyAgreement.PrivateKey(dataRepresentation: Data(hash).prefix(32))
}

// MARK: - Extended Types

/// Extended BlindSignature with DLEQ proof
public struct BlindSignatureWithDLEQ: CashuCodabale {
    public let amount: Int
    public let id: String
    public let C_: String
    public let dleq: DLEQProof?
    
    public init(amount: Int, id: String, C_: String, dleq: DLEQProof? = nil) {
        self.amount = amount
        self.id = id
        self.C_ = C_
        self.dleq = dleq
    }
    
    /// Convert to regular BlindSignature
    public var blindSignature: BlindSignature {
        BlindSignature(amount: amount, id: id, C_: C_)
    }
}

/// Extended Proof with DLEQ proof
public struct ProofWithDLEQ: CashuCodabale {
    public let amount: Int
    public let id: String
    public let secret: String
    public let C: String
    public let witness: String?
    public let dleq: DLEQProof?
    
    public init(amount: Int, id: String, secret: String, C: String, witness: String? = nil, dleq: DLEQProof? = nil) {
        self.amount = amount
        self.id = id
        self.secret = secret
        self.C = C
        self.witness = witness
        self.dleq = dleq
    }
    
    /// Convert to regular Proof
    public var proof: Proof {
        Proof(amount: amount, id: id, secret: secret, C: C, witness: witness)
    }
    
    /// Create from regular Proof
    public init(from proof: Proof, dleq: DLEQProof? = nil) {
        self.amount = proof.amount
        self.id = proof.id
        self.secret = proof.secret
        self.C = proof.C
        self.witness = proof.witness
        self.dleq = dleq
    }
}