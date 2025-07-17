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
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return preimage
    }
    
    private static func generateNonce() -> String {
        var nonce = Data(count: 16)
        _ = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.baseAddress!)
        }
        return nonce.hexString
    }
}

// MARK: - HTLC Wallet Extensions

extension CashuWallet {
    
    /// Create HTLC-locked proofs
    /// - Parameters:
    ///   - amount: Amount to lock
    ///   - preimage: The preimage for the HTLC
    ///   - pubkeys: Public keys that can spend with the preimage
    ///   - locktime: Optional locktime for refund
    ///   - refundKey: Optional refund public key
    /// - Returns: HTLC-locked proofs
    public func createHTLCProofs(
        amount: Int,
        preimage: Data,
        pubkeys: [String],
        locktime: Int64? = nil,
        refundKey: String? = nil
    ) async throws -> [Proof] {
        // Create HTLC secret
        let _ = try HTLCCreator.createHTLCSecret(
            preimage: preimage,
            pubkeys: pubkeys,
            locktime: locktime,
            refundKey: refundKey
        )
        
        // For now, we need to create proofs with custom secrets
        // This would need to be implemented in the actual swap method
        // Currently returning empty array as placeholder
        
        // TODO: Implement actual swap with custom secrets
        return []
    }
    
    /// Spend HTLC-locked proofs
    /// - Parameters:
    ///   - proofs: HTLC-locked proofs to spend
    ///   - witness: HTLC witness with preimage and signatures
    /// - Returns: New unlocked proofs
    public func spendHTLCProofs(
        proofs: [Proof],
        witness: HTLCWitness
    ) async throws -> SwapResult {
        // Verify all proofs are HTLC type
        for proof in proofs {
            guard let secret = try? WellKnownSecret.fromString(proof.secret),
                  secret.isHTLC else {
                throw CashuError.invalidProofType
            }
        }
        
        // Create witness JSON
        let witnessData = try JSONEncoder().encode(witness)
        let witnessString = String(data: witnessData, encoding: .utf8) ?? ""
        
        // Create BlindedMessage with witness
        var blindedMessages: [BlindedMessage] = []
        for proof in proofs {
            let message = BlindedMessage(
                amount: proof.amount,
                id: proof.id,
                B_: proof.C,  // Using C as B_ for spending
                witness: witnessString
            )
            blindedMessages.append(message)
        }
        
        // Perform swap with witness
        return try await swapWithWitness(
            inputs: proofs,
            outputs: blindedMessages
        )
    }
    
    /// Internal method to handle swap with witness data
    private func swapWithWitness(
        inputs: [Proof],
        outputs: [BlindedMessage]
    ) async throws -> SwapResult {
        // This would use the regular swap endpoint but with witness data included
        // The actual implementation depends on the mint's API
        
        // TODO: Implement actual swap with witness data
        // This would need to use the mint's swap endpoint with witness support
        return SwapResult(
            newProofs: [],
            invalidatedProofs: inputs,
            swapType: .send,
            totalAmount: inputs.reduce(0) { $0 + $1.amount },
            fees: 0
        )
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