//
//  NUT00_BlindDiffieHellmanKeyExchange.swift
//  CashuKit
//
//  NUT-00: Blind Diffie-Hellman Key Exchange
//  https://github.com/cashubtc/nuts/blob/main/00.md
//

import Foundation
import K1
import CryptoKit

// MARK: - NUT-00: Blind Diffie-Hellman Key Exchange

/// Domain separator for hash-to-curve operations in Cashu
private let DOMAIN_SEPARATOR = "Secp256k1_HashToCurve_Cashu_".data(using: .utf8)!

// MARK: - Hash to Curve Implementation (NUT-00 Specification)

/// Maps a message to a public key point on the secp256k1 curve
/// Y = hash_to_curve(x) where x is the secret message
/// Implementation follows NUT-00: Y = PublicKey('02' || SHA256(msg_hash || counter))
public func hashToCurve(_ message: Data) throws -> K1.Group.Point {
    // Create message hash: SHA256(DOMAIN_SEPARATOR || x)
    let msgHash = SHA256.hash(data: DOMAIN_SEPARATOR + message)
    
    // Try different counter values until we find a valid point
    for counter in 0..<UInt32.max {
        // Convert counter to little-endian bytes
        let counterBytes = withUnsafeBytes(of: counter.littleEndian) { Data($0) }
        
        // Create candidate: SHA256(msg_hash || counter)
        let candidate = SHA256.hash(data: Data(msgHash) + counterBytes)
        
        // Try to create a public key with prefix '02' (compressed format)
        let candidateWithPrefix = Data([0x02]) + candidate
        
        do {
            let publicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: candidateWithPrefix)
            return try K1.Group.Point(publicKey: publicKey)
        } catch {
            // This candidate doesn't form a valid point, try next counter
            continue
        }
    }
    
    throw CashuError.hashToCurveFailed
}

/// Convenience function for string messages
public func hashToCurve(_ message: String) throws -> K1.Group.Point {
    guard let data = message.data(using: .utf8) else {
        throw CashuError.invalidSecretLength
    }
    return try hashToCurve(data)
}

// MARK: - Generator Point

/// Get the secp256k1 generator point G
public func getGeneratorPoint() throws -> K1.Group.Point {
    // Create a private key with value 1 to get G = 1*G
    let oneData = Data([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
    ])
    
    let privateKeyOne = try K1.KeyAgreement.PrivateKey(rawRepresentation: oneData)
    let generatorPublicKey = privateKeyOne.publicKey
    return try K1.Group.Point(publicKey: generatorPublicKey)
}

// MARK: - Scalar Multiplication

/// Multiply a point by a scalar (private key): scalar * point
/// This implements k * P where k is a private key and P is a point
public func multiplyPoint(_ point: K1.Group.Point, by scalar: K1.KeyAgreement.PrivateKey) throws -> K1.Group.Point {
    // Convert point to public key for scalar multiplication
    let publicKey = try point.toPublicKey()
    
    // Use ECDH point function to get scalar * point without hashing
    let resultData = try scalar.ecdhPoint(with: publicKey)
    
    // Parse the uncompressed point data (65 bytes: 0x04 + 32 bytes x + 32 bytes y)
    guard resultData.count == 65 && resultData[0] == 0x04 else {
        throw CashuError.invalidPoint
    }
    
    let x = resultData[1..<33]
    let y = resultData[33..<65]
    
    return try K1.Group.Point(x: Data(x), y: Data(y))
}

// MARK: - Mint Implementation

/// Represents a mint's cryptographic keys for one amount
/// Each amount has its own key pair in Cashu
public struct MintKeypair {
    /// k: private key of mint (one for each amount)
    public let privateKey: K1.KeyAgreement.PrivateKey
    /// K: public key corresponding to k (K = k*G)
    public let publicKey: K1.KeyAgreement.PublicKey
    public let publicKeyPoint: K1.Group.Point
    
    public init() throws {
        self.privateKey = K1.KeyAgreement.PrivateKey()
        self.publicKey = privateKey.publicKey
        self.publicKeyPoint = try K1.Group.Point(publicKey: publicKey)
    }
    
    public init(privateKey: K1.KeyAgreement.PrivateKey) throws {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
        self.publicKeyPoint = try K1.Group.Point(publicKey: publicKey)
    }
}

/// Mint operations in the BDHKE protocol
public struct Mint {
    public let keypair: MintKeypair
    
    public init() throws {
        self.keypair = try MintKeypair()
    }
    
    public init(privateKey: K1.KeyAgreement.PrivateKey) throws {
        self.keypair = try MintKeypair(privateKey: privateKey)
    }
    
    /// Step 2 of BDHKE: Mint signs the blinded message
    /// Input: B_ (blinded message from wallet)
    /// Output: C_ = k * B_ (blinded signature)
    public func signBlindedMessage(_ blindedMessage: Data) throws -> Data {
        // Parse B_ as a compressed public key
        let blindedMessagePublicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: blindedMessage)
        let blindedMessagePoint = try K1.Group.Point(publicKey: blindedMessagePublicKey)
        
        // Sign: C_ = k * B_
        let blindedSignature = try multiplyPoint(blindedMessagePoint, by: keypair.privateKey)
        
        // Return C_ as compressed public key data
        let signaturePublicKey = try blindedSignature.toPublicKey()
        return signaturePublicKey.compressedRepresentation
    }
    
    /// Step 4 of BDHKE: Verify an unblinded signature
    /// Check that k * hash_to_curve(x) == C
    /// This is how the mint verifies a token is valid when it's spent
    public func verifyToken(secret: String, signature: Data) throws -> Bool {
        // Parse the signature as a compressed public key
        let signaturePublicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: signature)
        _ = try K1.Group.Point(publicKey: signaturePublicKey)
        
        // Compute k * hash_to_curve(x)
        let secretPoint = try hashToCurve(secret)
        let expectedSignature = try multiplyPoint(secretPoint, by: keypair.privateKey)
        
        // Compare the points
        let expectedPublicKey = try expectedSignature.toPublicKey()
        return signaturePublicKey.compressedRepresentation == expectedPublicKey.compressedRepresentation
    }
}

// MARK: - Wallet Implementation

/// Represents wallet's blinding data for one token
public struct WalletBlindingData {
    /// x: UTF-8-encoded secret message
    public let secret: String
    /// r: blinding factor (private key)
    public let blindingFactor: K1.KeyAgreement.PrivateKey
    /// Y: hash_to_curve(x)
    public let secretPoint: K1.Group.Point
    /// B_: blinded message (Y + r*G)
    public let blindedMessage: K1.Group.Point
    
    public init(secret: String) throws {
        self.secret = secret
        self.blindingFactor = K1.KeyAgreement.PrivateKey()
        self.secretPoint = try hashToCurve(secret)
        
        // Create blinded message: B_ = Y + r*G
        let generatorPoint = try getGeneratorPoint()
        let rG = try multiplyPoint(generatorPoint, by: self.blindingFactor)
        self.blindedMessage = try K1.Group.add(self.secretPoint, rG)
    }
}

/// Represents an unblinded token
public struct UnblindedToken {
    /// x: the original secret
    public let secret: String
    /// C: unblinded signature
    public let signature: Data
    
    public init(secret: String, signature: Data) {
        self.secret = secret
        self.signature = signature
    }
}

/// Wallet operations in the BDHKE protocol
public struct Wallet {
    
    /// Step 1 of BDHKE: Create a blinded message for the mint to sign
    /// Input: x (secret)
    /// Output: B_ = Y + r*G where Y = hash_to_curve(x) and r is random
    public static func createBlindedMessage(secret: String) throws -> (blindingData: WalletBlindingData, blindedMessage: Data) {
        let blindingData = try WalletBlindingData(secret: secret)
        
        // Convert B_ to compressed public key format for transmission
        let blindedPublicKey = try blindingData.blindedMessage.toPublicKey()
        let blindedMessage = blindedPublicKey.compressedRepresentation
        
        return (blindingData, blindedMessage)
    }
    
    /// Step 3 of BDHKE: Unblind the signature received from the mint
    /// Input: C_ (blinded signature), blinding data, K (mint public key)
    /// Output: C = C_ - r*K (unblinded signature)
    public static func unblindSignature(
        blindedSignature: Data,
        blindingData: WalletBlindingData,
        mintPublicKey: K1.KeyAgreement.PublicKey
    ) throws -> UnblindedToken {
        // Parse C_ as a compressed public key
        let blindedSigPublicKey = try K1.KeyAgreement.PublicKey(compressedRepresentation: blindedSignature)
        let blindedSigPoint = try K1.Group.Point(publicKey: blindedSigPublicKey)
        
        // Unblind: C = C_ - r*K
        let mintPublicKeyPoint = try K1.Group.Point(publicKey: mintPublicKey)
        let rK = try multiplyPoint(mintPublicKeyPoint, by: blindingData.blindingFactor)
        let unblindedSignaturePoint = try K1.Group.subtract(blindedSigPoint, rK)
        
        // Convert to data for storage/transmission
        let unblindedSignaturePublicKey = try unblindedSignaturePoint.toPublicKey()
        let signatureData = unblindedSignaturePublicKey.compressedRepresentation
        
        return UnblindedToken(secret: blindingData.secret, signature: signatureData)
    }
    
    /// Verify a token locally (same logic as mint verification)
    public static func verifyToken(_ token: UnblindedToken, mintPublicKey: K1.KeyAgreement.PublicKey) throws -> Bool {
        _ = try Mint(privateKey: K1.KeyAgreement.PrivateKey()) // This won't work for verification
        // Note: This method can't work without the mint's private key
        // Token verification must be done by the mint
        throw CashuError.verificationFailed
    }
}

// MARK: - Protocol Flow Implementation

/// Complete BDHKE protocol flow following NUT-00
public struct CashuBDHKEProtocol {
    
    /// Execute the complete BDHKE protocol
    /// This demonstrates the full flow from NUT-00
    public static func executeProtocol(secret: String) throws -> (token: UnblindedToken, isValid: Bool) {
        print("=== Executing Cashu BDHKE Protocol (NUT-00) ===\n")
        
        // Setup: Mint publishes public key K = k*G
        let mint = try Mint()
        let mintPublicKey = mint.keypair.publicKey
        print("1. Mint publishes public key K: \(mintPublicKey.compressedRepresentation.hexString)")
        
        // Step 1: Wallet picks secret x and computes Y = hash_to_curve(x)
        //         Wallet sends B_ = Y + r*G to mint (blinding)
        let (blindingData, blindedMessage) = try Wallet.createBlindedMessage(secret: secret)
        print("2. Wallet creates secret x: \(secret)")
        print("   Wallet computes Y = hash_to_curve(x)")
        print("   Wallet sends B_ = Y + r*G: \(blindedMessage.hexString)")
        
        // Step 2: Mint signs the blinded message and sends back C_ = k*B_ (signing)
        let blindedSignature = try mint.signBlindedMessage(blindedMessage)
        print("3. Mint signs and returns C_ = k*B_: \(blindedSignature.hexString)")
        
        // Step 3: Wallet unblinds the signature: C = C_ - r*K (unblinding)
        let token = try Wallet.unblindSignature(
            blindedSignature: blindedSignature,
            blindingData: blindingData,
            mintPublicKey: mintPublicKey
        )
        print("4. Wallet unblinds to get C = C_ - r*K: \(token.signature.hexString)")
        
        // Step 4: Verification - Mint checks k*hash_to_curve(x) == C
        let isValid = try mint.verifyToken(secret: token.secret, signature: token.signature)
        print("5. Mint verifies k*hash_to_curve(x) == C: \(isValid)")
        
        print("\n=== Protocol Complete ===")
        return (token, isValid)
    }
} 