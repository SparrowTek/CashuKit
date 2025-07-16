//
//  NUT13.swift
//  CashuKit
//
//  NUT-13: Deterministic Secrets
//

import Foundation
import P256K
import CryptoKit
import CommonCrypto

// MARK: - NUT-13 Constants

enum NUT13Constants {
    static let purpose: UInt32 = 129372 // 🥜 in UTF-8
    static let coinType: UInt32 = 0
    static let maxKeysetInt: UInt32 = UInt32(1 << 31) - 1
}

// MARK: - Key Derivation

public struct DeterministicSecretDerivation: Sendable {
    private let masterKey: Data
    
    public init(masterKey: Data) {
        self.masterKey = masterKey
    }
    
    public init(mnemonic: String, passphrase: String = "") throws {
        let seed = try BIP39.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase)
        self.masterKey = BIP32.createMasterKey(seed: seed)
    }
    
    public func deriveSecret(keysetID: String, counter: UInt32) throws -> String {
        let keysetInt = try keysetIDToInt(keysetID)
        let path = secretDerivationPath(keysetInt: keysetInt, counter: counter)
        let privateKey = try derivePrivateKey(path: path)
        return privateKey.hexString
    }
    
    public func deriveBlindingFactor(keysetID: String, counter: UInt32) throws -> Data {
        let keysetInt = try keysetIDToInt(keysetID)
        let path = blindingFactorDerivationPath(keysetInt: keysetInt, counter: counter)
        return try derivePrivateKey(path: path)
    }
    
    private func secretDerivationPath(keysetInt: UInt32, counter: UInt32) -> [UInt32] {
        return [
            NUT13Constants.purpose | 0x80000000,  // 129372'
            NUT13Constants.coinType | 0x80000000, // 0'
            keysetInt | 0x80000000,               // keyset_id'
            counter | 0x80000000,                 // counter'
            0                                     // 0 for secret
        ]
    }
    
    private func blindingFactorDerivationPath(keysetInt: UInt32, counter: UInt32) -> [UInt32] {
        return [
            NUT13Constants.purpose | 0x80000000,  // 129372'
            NUT13Constants.coinType | 0x80000000, // 0'
            keysetInt | 0x80000000,               // keyset_id'
            counter | 0x80000000,                 // counter'
            1                                     // 1 for blinding factor
        ]
    }
    
    func keysetIDToInt(_ keysetID: String) throws -> UInt32 {
        guard let data = Data(hexString: keysetID) else {
            throw CashuError.invalidKeysetID
        }
        
        guard data.count == 8 else {
            throw CashuError.invalidKeysetID
        }
        
        let bigEndianValue = data.withUnsafeBytes { bytes in
            bytes.load(as: UInt64.self)
        }
        
        let value = UInt64(bigEndian: bigEndianValue)
        return UInt32(value % UInt64(NUT13Constants.maxKeysetInt))
    }
    
    private func derivePrivateKey(path: [UInt32]) throws -> Data {
        var key = masterKey
        
        for index in path {
            key = try BIP32.deriveChildKey(parentKey: key, index: index)
        }
        
        return Data(key.prefix(32))
    }
}

// MARK: - Counter Management

public actor KeysetCounterManager {
    private var counters: [String: UInt32] = [:]
    
    public func getCounter(for keysetID: String) -> UInt32 {
        return counters[keysetID] ?? 0
    }
    
    public func incrementCounter(for keysetID: String) {
        counters[keysetID] = (counters[keysetID] ?? 0) + 1
    }
    
    public func setCounter(for keysetID: String, value: UInt32) {
        counters[keysetID] = value
    }
    
    public func resetCounter(for keysetID: String) {
        counters[keysetID] = 0
    }
    
    public func getAllCounters() -> [String: UInt32] {
        return counters
    }
}

// MARK: - Wallet Restoration

public struct WalletRestoration: Sendable {
    public let derivation: DeterministicSecretDerivation
    private let counterManager: KeysetCounterManager
    
    public init(derivation: DeterministicSecretDerivation, counterManager: KeysetCounterManager) {
        self.derivation = derivation
        self.counterManager = counterManager
    }
    
    public func generateBlindedMessages(
        keysetID: String,
        startCounter: UInt32,
        batchSize: Int = 100
    ) async throws -> [(BlindedMessage, Data)] {
        var results: [(BlindedMessage, Data)] = []
        
        for offset in 0..<batchSize {
            let counter = startCounter + UInt32(offset)
            
            let secret = try derivation.deriveSecret(keysetID: keysetID, counter: counter)
            let r = try derivation.deriveBlindingFactor(keysetID: keysetID, counter: counter)
            
            let blindedMessage = try await createBlindedMessage(
                secret: secret,
                blindingFactor: r,
                keysetID: keysetID
            )
            
            results.append((blindedMessage, r))
        }
        
        return results
    }
    
    public func restoreProofs(
        blindedSignatures: [BlindSignature],
        blindingFactors: [Data],
        secrets: [String],
        keysetID: String,
        mintPublicKey: P256K.KeyAgreement.PublicKey
    ) throws -> [Proof] {
        guard blindedSignatures.count == blindingFactors.count,
              blindingFactors.count == secrets.count else {
            throw CashuError.mismatchedArrayLengths
        }
        
        var proofs: [Proof] = []
        
        for i in 0..<blindedSignatures.count {
            let signature = blindedSignatures[i]
            let r = blindingFactors[i]
            let secret = secrets[i]
            
            let C = try unblindSignature(blindedSignature: signature, r: r, mintPublicKey: mintPublicKey)
            
            let proof = Proof(
                amount: signature.amount,
                id: keysetID,
                secret: secret,
                C: C
            )
            
            proofs.append(proof)
        }
        
        return proofs
    }
    
    private func createBlindedMessage(
        secret: String,
        blindingFactor: Data,
        keysetID: String
    ) async throws -> BlindedMessage {
        let B_ = try blindMessage(secret: secret, r: blindingFactor)
        
        return BlindedMessage(
            amount: 0,
            id: keysetID,
            B_: B_
        )
    }
    
    private func blindMessage(secret: String, r: Data) throws -> String {
        guard let secretData = Data(hexString: secret) else {
            throw CashuError.invalidSecret
        }
        
        // Y = hash_to_curve(secret)
        let Y = try hashToCurve(secretData)
        
        // r*G
        let rPrivateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: r)
        let G = try getGeneratorPoint()
        let rG = try multiplyPoint(G, by: rPrivateKey)
        
        // B_ = Y + r*G
        let B_ = try addPoints(Y, rG)
        
        return B_.dataRepresentation.hexString
    }
    
    private func unblindSignature(blindedSignature: BlindSignature, r: Data, mintPublicKey: P256K.KeyAgreement.PublicKey) throws -> String {
        guard let blindedSigData = Data(hexString: blindedSignature.C_) else {
            throw CashuError.invalidSignature("Invalid hex in blinded signature")
        }
        
        let C_ = try P256K.KeyAgreement.PublicKey(dataRepresentation: blindedSigData, format: .compressed)
        let rPrivateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: r)
        
        // Unblind: C = C_ - r*K
        let rK = try multiplyPoint(mintPublicKey, by: rPrivateKey)
        let C = try subtractPoints(C_, rK)
        
        return C.dataRepresentation.hexString
    }
}


// MARK: - BIP32 Support

public struct BIP32 {
    private static let curveOrder = Data(hexString: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")!
    
    public static func createMasterKey(seed: Data) -> Data {
        let hmac = HMAC.sha512(key: "Bitcoin seed".data(using: .utf8)!, data: seed)
        return hmac
    }
    
    public static func deriveChildKey(parentKey: Data, index: UInt32) throws -> Data {
        let chainCode = parentKey.suffix(32)
        let privateKey = parentKey.prefix(32)
        
        var data = Data()
        if index & 0x80000000 != 0 {
            data.append(0x00)
            data.append(privateKey)
        } else {
            let privateKeyObject = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateKey)
            data.append(privateKeyObject.publicKey.dataRepresentation)
        }
        
        let indexBytes = index.bigEndianBytes
        data.append(contentsOf: indexBytes)
        
        let hmac = HMAC.sha512(key: chainCode, data: data)
        let childPrivateKey = hmac.prefix(32)
        let childChainCode = hmac.suffix(32)
        
        var result = Data()
        result.append(childPrivateKey)
        result.append(childChainCode)
        
        return result
    }
}

// MARK: - Extensions

// MARK: - Restoration Result Types

public struct RestoreBatch {
    public let keysetID: String
    public let startCounter: UInt32
    public let endCounter: UInt32
    public let proofs: [Proof]
    public let spentProofs: [Proof]
    public let unspentProofs: [Proof]
    
    public var isEmpty: Bool {
        return proofs.isEmpty
    }
    
    public var hasUnspentProofs: Bool {
        return !unspentProofs.isEmpty
    }
}

public struct RestorationProgress: Sendable {
    public let keysetID: String
    public let currentCounter: UInt32
    public let totalProofsFound: Int
    public let unspentProofsFound: Int
    public let consecutiveEmptyBatches: Int
    public let isComplete: Bool
    public let error: (any Error)?
    
    public init(
        keysetID: String,
        currentCounter: UInt32,
        totalProofsFound: Int,
        unspentProofsFound: Int,
        consecutiveEmptyBatches: Int,
        isComplete: Bool,
        error: (any Error)? = nil
    ) {
        self.keysetID = keysetID
        self.currentCounter = currentCounter
        self.totalProofsFound = totalProofsFound
        self.unspentProofsFound = unspentProofsFound
        self.consecutiveEmptyBatches = consecutiveEmptyBatches
        self.isComplete = isComplete
        self.error = error
    }
}

// MARK: - Helpers

extension Data {
    static func random(count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, count, bytes.baseAddress!)
        }
        return data
    }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        return [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF)
        ]
    }
}

// MARK: - Crypto Helpers

struct HMAC {
    static func sha512(key: Data, data: Data) -> Data {
        let key = CryptoKit.SymmetricKey(data: key)
        let hmac = CryptoKit.HMAC<CryptoKit.SHA512>.authenticationCode(for: data, using: key)
        return Data(hmac)
    }
}


