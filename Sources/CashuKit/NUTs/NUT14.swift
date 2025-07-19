//
//  NUT14.swift
//  CashuKit
//
//  NUT-14: Hashed Timelock Contracts (HTLCs)
//

import Foundation
import CryptoKit
import P256K

// MARK: - HTLC Types

/// Witness format for HTLC spending conditions
public struct HTLCWitness: Codable, Sendable {
    /// Preimage that hashes to the lock in Secret.data
    public let preimage: String
    
    /// Signatures from authorized keys
    public let signatures: [String]
    
    public init(preimage: String, signatures: [String]) {
        self.preimage = preimage
        self.signatures = signatures
    }
}

// MARK: - HTLC Secret Extensions

extension WellKnownSecret {
    /// Check if this secret is an HTLC type
    public var isHTLC: Bool {
        return kind == SpendingConditionKind.htlc
    }
    
    /// Get the hash lock from an HTLC secret
    public var hashLock: String? {
        guard isHTLC else { return nil }
        return secretData.data
    }
    
    /// Check if the HTLC has a refund condition
    public var hasRefundCondition: Bool {
        guard isHTLC else { return false }
        return secretData.tags?.first(where: { $0.first == "refund" }) != nil
    }
    
    /// Get the refund public key if present
    public var refundPublicKey: String? {
        guard isHTLC else { return nil }
        return secretData.tags?.first(where: { $0.first == "refund" })?.dropFirst().first
    }
    
    /// Get public keys from HTLC secret
    public var pubkeys: [String]? {
        guard isHTLC else { return nil }
        return secretData.tags?.compactMap { tag in
            tag.first == "pubkeys" ? Array(tag.dropFirst()) : nil
        }.flatMap { $0 }
    }
    
    /// Get locktime from HTLC secret
    public var locktime: Int64? {
        guard isHTLC else { return nil }
        guard let locktimeStr = secretData.tags?.first(where: { $0.first == "locktime" })?.dropFirst().first else {
            return nil
        }
        return Int64(locktimeStr)
    }
}

// MARK: - HTLC Verification

public struct HTLCVerifier: Sendable {
    
    /// Verify an HTLC proof
    /// - Parameters:
    ///   - proof: The proof to verify
    ///   - witness: The witness data
    ///   - currentTime: Current timestamp for locktime verification
    /// - Returns: True if the proof is valid
    public static func verifyHTLC(
        proof: Proof,
        witness: HTLCWitness,
        currentTime: Int64 = Int64(Date().timeIntervalSince1970)
    ) throws -> Bool {
        guard let secret = try? WellKnownSecret.fromString(proof.secret),
              secret.isHTLC else {
            throw CashuError.invalidSecret
        }
        
        // Verify the preimage matches the hash lock
        let preimageVerified = try verifyPreimage(
            preimage: witness.preimage,
            hashLock: secret.hashLock ?? ""
        )
        
        // If preimage verification fails, check refund conditions
        if !preimageVerified {
            // Check if locktime has passed for refund
            if let locktime = secret.locktime,
               currentTime < locktime {
                throw CashuError.locktimeNotExpired
            }
            
            // Verify refund signature if preimage check failed
            if let refundKey = secret.refundPublicKey {
                return try verifyRefundSignature(
                    secret: secret,
                    witness: witness,
                    refundKey: refundKey
                )
            }
            
            return false
        }
        
        // Verify signatures for authorized public keys
        guard let pubkeys = secret.pubkeys, !pubkeys.isEmpty else {
            // If no pubkeys specified, preimage alone is sufficient
            return preimageVerified
        }
        
        return try verifySignatures(
            secret: secret,
            witness: witness,
            pubkeys: pubkeys
        )
    }
    
    /// Verify the preimage matches the hash lock
    static func verifyPreimage(preimage: String, hashLock: String) throws -> Bool {
        guard let preimageData = Data(hexString: preimage),
              preimageData.count == 32 else {
            throw CashuError.invalidPreimage
        }
        
        let hash = SHA256.hash(data: preimageData)
        let hashHex = Data(hash).hexString
        
        return hashHex == hashLock.lowercased()
    }
    
    /// Verify signatures for authorized public keys
    private static func verifySignatures(
        secret: WellKnownSecret,
        witness: HTLCWitness,
        pubkeys: [String]
    ) throws -> Bool {
        // Check if we need all signatures (n-of-n) or any signature (1-of-n)
        let requireAllSignatures = secret.secretData.tags?.contains(where: { $0.first == "n_sigs" }) ?? false
        
        if requireAllSignatures {
            // Verify all pubkeys have signed
            guard witness.signatures.count == pubkeys.count else {
                return false
            }
            
            for (index, pubkey) in pubkeys.enumerated() {
                guard index < witness.signatures.count else { return false }
                
                let signature = witness.signatures[index]
                let verified = P2PKSignatureValidator.validateSignature(
                    signature: signature,
                    publicKey: pubkey,
                    message: secret.secretData.nonce
                )
                
                if !verified {
                    return false
                }
            }
            
            return true
        } else {
            // Verify at least one valid signature
            for signature in witness.signatures {
                for pubkey in pubkeys {
                    let verified = P2PKSignatureValidator.validateSignature(
                        signature: signature,
                        publicKey: pubkey,
                        message: secret.secretData.nonce
                    )
                    if verified {
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    /// Verify refund signature
    private static func verifyRefundSignature(
        secret: WellKnownSecret,
        witness: HTLCWitness,
        refundKey: String
    ) throws -> Bool {
        // For refund, we need at least one valid signature from the refund key
        for signature in witness.signatures {
            let verified = P2PKSignatureValidator.validateSignature(
                signature: signature,
                publicKey: refundKey,
                message: secret.secretData.nonce
            )
            
            if verified {
                return true
            }
        }
        
        return false
    }
}

// MARK: - HTLC Witness Helper

extension HTLCWitness {
    /// Create witness for spending with preimage only
    public static func createForPreimage(_ preimage: Data) -> HTLCWitness {
        return HTLCWitness(
            preimage: preimage.hexString,
            signatures: []
        )
    }
    
    /// Create witness for spending with preimage and signatures
    public static func createForPreimageAndSignatures(
        preimage: Data,
        signatures: [(privateKey: P256K.KeyAgreement.PrivateKey, message: String)]
    ) throws -> HTLCWitness {
        var signatureStrings: [String] = []
        
        for (privateKey, message) in signatures {
            // Create signature using P256K
            guard let messageData = message.data(using: .utf8) else {
                throw CashuError.invalidSignature("Invalid message encoding")
            }
            
            // For P2PK signatures, we need to use a deterministic nonce
            // This is a simplified version - in production you'd use proper ECDSA
            let messageHash = SHA256.hash(data: messageData)
            let hashData = Data(messageHash)
            
            // Create a mock signature for now (64 bytes: r + s)
            // In a real implementation, you'd use proper ECDSA signing
            let mockSignature = hashData + hashData
            let signature = mockSignature.hexString
            
            signatureStrings.append(signature)
        }
        
        return HTLCWitness(
            preimage: preimage.hexString,
            signatures: signatureStrings
        )
    }
    
    /// Create witness for refund (signatures only, no preimage)
    public static func createForRefund(
        signatures: [(privateKey: P256K.KeyAgreement.PrivateKey, message: String)]
    ) throws -> HTLCWitness {
        var signatureStrings: [String] = []
        
        for (privateKey, message) in signatures {
            // Create signature using P256K
            guard let messageData = message.data(using: .utf8) else {
                throw CashuError.invalidSignature("Invalid message encoding")
            }
            
            // For P2PK signatures, we need to use a deterministic nonce
            // This is a simplified version - in production you'd use proper ECDSA
            let messageHash = SHA256.hash(data: messageData)
            let hashData = Data(messageHash)
            
            // Create a mock signature for now (64 bytes: r + s)
            // In a real implementation, you'd use proper ECDSA signing
            let mockSignature = hashData + hashData
            let signature = mockSignature.hexString
            
            signatureStrings.append(signature)
        }
        
        // Use empty/zero preimage for refund
        let zeroPreimage = Data(repeating: 0, count: 32)
        
        return HTLCWitness(
            preimage: zeroPreimage.hexString,
            signatures: signatureStrings
        )
    }
}

// MARK: - HTLC Creation

public struct HTLCCreator: Sendable {
    
    /// Create an HTLC secret
    /// - Parameters:
    ///   - preimage: The preimage (32 bytes)
    ///   - pubkeys: Public keys that can spend with the preimage
    ///   - locktime: Optional locktime for refund condition
    ///   - refundKey: Optional refund public key
    ///   - sigflag: Signature flag (default: SIG_ALL)
    /// - Returns: Encoded secret string
    public static func createHTLCSecret(
        preimage: Data,
        pubkeys: [String],
        locktime: Int64? = nil,
        refundKey: String? = nil,
        sigflag: SignatureFlag = .sigAll
    ) throws -> String {
        guard preimage.count == 32 else {
            throw CashuError.invalidPreimage
        }
        
        // Generate nonce
        let nonce = generateNonce()
        
        // Calculate hash lock
        let hashLock = SHA256.hash(data: preimage)
        let hashLockHex = Data(hashLock).hexString
        
        // Build tags
        var tags: [[String]] = []
        
        // Add pubkeys
        if !pubkeys.isEmpty {
            tags.append(["pubkeys"] + pubkeys)
        }
        
        // Add locktime if specified
        if let locktime = locktime {
            tags.append(["locktime", String(locktime)])
        }
        
        // Add refund key if specified
        if let refundKey = refundKey {
            tags.append(["refund", refundKey])
        }
        
        // Add signature flag if not default
        if sigflag != .sigAll {
            tags.append(["sigflag", sigflag.rawValue])
        }
        
        // Create secret
        let secretData = WellKnownSecret.SecretData(
            nonce: nonce,
            data: hashLockHex,
            tags: tags.isEmpty ? nil : tags
        )
        
        let secret = WellKnownSecret(
            kind: SpendingConditionKind.htlc,
            secretData: secretData
        )
        
        return try secret.toJSONString()
    }
    
    /// Generate a random 32-byte preimage
    public static func generatePreimage() -> Data {
        var preimage = Data(count: 32)
        _ = preimage.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, 32, baseAddress)
        }
        return preimage
    }
    
    private static func generateNonce() -> String {
        var nonce = Data(count: 16)
        _ = nonce.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, 16, baseAddress)
        }
        return nonce.hexString
    }
}

// MARK: - HTLC Helper Functions

/// Helper functions for HTLC operations
public struct HTLCHelper: Sendable {
    
    /// Create an HTLC-locked secret that can be used in proof creation
    /// - Parameters:
    ///   - preimage: The preimage for the HTLC
    ///   - pubkeys: Public keys that can spend with the preimage
    ///   - locktime: Optional locktime for refund
    ///   - refundKey: Optional refund public key
    /// - Returns: HTLC secret string
    public static func createHTLCSecret(
        preimage: Data,
        pubkeys: [String],
        locktime: Int64? = nil,
        refundKey: String? = nil
    ) throws -> String {
        return try HTLCCreator.createHTLCSecret(
            preimage: preimage,
            pubkeys: pubkeys,
            locktime: locktime,
            refundKey: refundKey
        )
    }
    
    /// Verify HTLC proofs can be spent with given witness
    /// - Parameters:
    ///   - proofs: HTLC-locked proofs to verify
    ///   - witness: HTLC witness with preimage and signatures
    /// - Returns: True if all proofs can be spent with the witness
    public static func verifyHTLCProofs(
        proofs: [Proof],
        witness: HTLCWitness
    ) throws -> Bool {
        // Verify all proofs are HTLC type and can be spent with witness
        for proof in proofs {
            guard let secret = try? WellKnownSecret.fromString(proof.secret),
                  secret.isHTLC else {
                throw CashuError.invalidProofType
            }
            
            // Verify the witness is valid for this proof
            let isValid = try HTLCVerifier.verifyHTLC(
                proof: proof,
                witness: witness
            )
            
            if !isValid {
                return false
            }
        }
        
        return true
    }
    
    /// Attach witness data to proofs for spending
    /// - Parameters:
    ///   - proofs: HTLC-locked proofs
    ///   - witness: HTLC witness data
    /// - Returns: Proofs with witness attached
    public static func attachWitnessToProofs(
        proofs: [Proof],
        witness: HTLCWitness
    ) throws -> [Proof] {
        // Create witness JSON
        let witnessData = try JSONEncoder().encode(witness)
        let witnessString = String(data: witnessData, encoding: .utf8) ?? ""
        
        // Create proofs with witness attached
        var witnessProofs: [Proof] = []
        for proof in proofs {
            let witnessProof = Proof(
                amount: proof.amount,
                id: proof.id,
                secret: proof.secret,
                C: proof.C,
                witness: witnessString,
                dleq: proof.dleq
            )
            witnessProofs.append(witnessProof)
        }
        
        return witnessProofs
    }
}

// MARK: - Mint Info Extensions

extension MintInfo {
    /// Check if the mint supports NUT-14 (HTLCs)
    public var supportsHTLC: Bool {
        return supportsNUT("14")
    }
    
    /// Get NUT-14 settings if supported
    public func getNUT14Settings() -> NUT14Settings? {
        guard let nut14Data = nuts?["14"]?.dictionaryValue else { return nil }
        
        let supported = nut14Data["supported"] as? Bool ?? false
        
        return NUT14Settings(supported: supported)
    }
}

/// NUT-14 settings from mint info
public struct NUT14Settings: Codable, Sendable {
    public let supported: Bool
    
    public init(supported: Bool) {
        self.supported = supported
    }
}