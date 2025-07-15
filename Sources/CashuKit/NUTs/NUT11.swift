import Foundation
import CryptoKit

public enum SignatureFlag: String, CaseIterable, Sendable {
    case sigInputs = "SIG_INPUTS"
    case sigAll = "SIG_ALL"
}

public struct P2PKWitness: Codable, Equatable, Sendable {
    public let signatures: [String]
    
    public init(signatures: [String]) {
        self.signatures = signatures
    }
    
    public func toJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CashuError.serializationFailed
        }
        return string
    }
    
    public static func fromString(_ string: String) throws -> P2PKWitness {
        guard let data = string.data(using: .utf8) else {
            throw CashuError.deserializationFailed
        }
        return try JSONDecoder().decode(P2PKWitness.self, from: data)
    }
}

public struct P2PKSpendingCondition: Sendable {
    public let publicKey: String
    public let nonce: String
    public let signatureFlag: SignatureFlag
    public let requiredSigs: Int
    public let additionalPubkeys: [String]
    public let locktime: Int?
    public let refundPubkeys: [String]
    
    public init(
        publicKey: String,
        nonce: String? = nil,
        signatureFlag: SignatureFlag = .sigInputs,
        requiredSigs: Int = 1,
        additionalPubkeys: [String] = [],
        locktime: Int? = nil,
        refundPubkeys: [String] = []
    ) {
        self.publicKey = publicKey
        self.nonce = nonce ?? WellKnownSecret.generateNonce()
        self.signatureFlag = signatureFlag
        self.requiredSigs = requiredSigs
        self.additionalPubkeys = additionalPubkeys
        self.locktime = locktime
        self.refundPubkeys = refundPubkeys
    }
    
    public func toWellKnownSecret() -> WellKnownSecret {
        var tags: [[String]] = []
        
        tags.append(["sigflag", signatureFlag.rawValue])
        
        if requiredSigs > 1 {
            tags.append(["n_sigs", String(requiredSigs)])
        }
        
        for pubkey in additionalPubkeys {
            tags.append(["pubkeys", pubkey])
        }
        
        if let locktime = locktime {
            tags.append(["locktime", String(locktime)])
        }
        
        for refundKey in refundPubkeys {
            tags.append(["refund", refundKey])
        }
        
        let secretData = WellKnownSecret.SecretData(
            nonce: nonce,
            data: publicKey,
            tags: tags.isEmpty ? nil : tags
        )
        
        return WellKnownSecret(kind: SpendingConditionKind.p2pk, secretData: secretData)
    }
    
    public static func fromWellKnownSecret(_ secret: WellKnownSecret) throws -> P2PKSpendingCondition {
        guard secret.kind == SpendingConditionKind.p2pk else {
            throw CashuError.invalidTokenFormat
        }
        
        let publicKey = secret.secretData.data
        let nonce = secret.secretData.nonce
        var signatureFlag = SignatureFlag.sigInputs
        var requiredSigs = 1
        var additionalPubkeys: [String] = []
        var locktime: Int? = nil
        var refundPubkeys: [String] = []
        
        if let tags = secret.secretData.tags {
            for tag in tags {
                guard tag.count >= 2 else { continue }
                
                switch tag[0] {
                case "sigflag":
                    signatureFlag = SignatureFlag(rawValue: tag[1]) ?? .sigInputs
                case "n_sigs":
                    requiredSigs = Int(tag[1]) ?? 1
                case "pubkeys":
                    additionalPubkeys.append(contentsOf: tag.dropFirst())
                case "locktime":
                    locktime = Int(tag[1])
                case "refund":
                    refundPubkeys.append(contentsOf: tag.dropFirst())
                default:
                    break
                }
            }
        }
        
        return P2PKSpendingCondition(
            publicKey: publicKey,
            nonce: nonce,
            signatureFlag: signatureFlag,
            requiredSigs: requiredSigs,
            additionalPubkeys: additionalPubkeys,
            locktime: locktime,
            refundPubkeys: refundPubkeys
        )
    }
    
    public func getAllPossibleSigners() -> [String] {
        var signers = [publicKey]
        signers.append(contentsOf: additionalPubkeys)
        return signers
    }
    
    public func isExpired() -> Bool {
        guard let locktime = locktime else { return false }
        return Int(Date().timeIntervalSince1970) > locktime
    }
    
    public func canBeSpentByRefund() -> Bool {
        return isExpired() && !refundPubkeys.isEmpty
    }
    
    public func canBeSpentByAnyone() -> Bool {
        return isExpired() && refundPubkeys.isEmpty
    }
}

public extension P2PKSpendingCondition {
    static func simple(publicKey: String) -> P2PKSpendingCondition {
        return P2PKSpendingCondition(publicKey: publicKey)
    }
    
    static func multisig(
        publicKeys: [String],
        requiredSigs: Int,
        signatureFlag: SignatureFlag = .sigInputs
    ) -> P2PKSpendingCondition {
        guard !publicKeys.isEmpty else {
            fatalError("At least one public key required")
        }
        
        let primaryKey = publicKeys[0]
        let additionalKeys = Array(publicKeys.dropFirst())
        
        return P2PKSpendingCondition(
            publicKey: primaryKey,
            signatureFlag: signatureFlag,
            requiredSigs: requiredSigs,
            additionalPubkeys: additionalKeys
        )
    }
    
    static func timelocked(
        publicKey: String,
        locktime: Int,
        refundPubkeys: [String] = []
    ) -> P2PKSpendingCondition {
        return P2PKSpendingCondition(
            publicKey: publicKey,
            locktime: locktime,
            refundPubkeys: refundPubkeys
        )
    }
}

public struct P2PKSignatureValidator {
    
    public static func validateSignature(
        signature: String,
        publicKey: String,
        message: String
    ) -> Bool {
        guard let signatureData = Data(hexString: signature),
              let publicKeyData = Data(hexString: publicKey),
              let messageData = message.data(using: .utf8) else {
            return false
        }
        
        let messageHash = SHA256.hash(data: messageData)
        
        do {
            let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            return key.isValidSignature(signatureData, for: Data(messageHash))
        } catch {
            return false
        }
    }
    
    public static func validateSignatureOnBytes(
        signature: String,
        publicKey: String,
        messageBytes: Data
    ) -> Bool {
        guard let signatureData = Data(hexString: signature),
              let publicKeyData = Data(hexString: publicKey) else {
            return false
        }
        
        let messageHash = SHA256.hash(data: messageBytes)
        
        do {
            let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            return key.isValidSignature(signatureData, for: Data(messageHash))
        } catch {
            return false
        }
    }
    
    public static func validateProofSignatures(
        proof: Proof,
        condition: P2PKSpendingCondition
    ) -> Bool {
        guard let witness = proof.getP2PKWitness() else {
            return false
        }
        
        let availableSigners = condition.getAllPossibleSigners()
        var validSignatureCount = 0
        
        for signature in witness.signatures {
            for signer in availableSigners {
                if validateSignature(signature: signature, publicKey: signer, message: proof.secret) {
                    validSignatureCount += 1
                    break
                }
            }
        }
        
        if condition.canBeSpentByRefund() {
            for signature in witness.signatures {
                for refundKey in condition.refundPubkeys {
                    if validateSignature(signature: signature, publicKey: refundKey, message: proof.secret) {
                        return true
                    }
                }
            }
        }
        
        return validSignatureCount >= condition.requiredSigs
    }
    
    public static func validateBlindedMessageSignatures(
        blindedMessage: BlindedMessage,
        condition: P2PKSpendingCondition
    ) -> Bool {
        guard let witness = blindedMessage.getP2PKWitness(),
              let messageBytes = Data(hexString: blindedMessage.B_) else {
            return false
        }
        
        let availableSigners = condition.getAllPossibleSigners()
        var validSignatureCount = 0
        
        for signature in witness.signatures {
            for signer in availableSigners {
                if validateSignatureOnBytes(signature: signature, publicKey: signer, messageBytes: messageBytes) {
                    validSignatureCount += 1
                    break
                }
            }
        }
        
        if condition.canBeSpentByRefund() {
            for signature in witness.signatures {
                for refundKey in condition.refundPubkeys {
                    if validateSignatureOnBytes(signature: signature, publicKey: refundKey, messageBytes: messageBytes) {
                        return true
                    }
                }
            }
        }
        
        return validSignatureCount >= condition.requiredSigs
    }
    
    public static func validateSpendingConditions(
        proofs: [Proof],
        blindedMessages: [BlindedMessage] = []
    ) -> Bool {
        var requiresAllSignatures = false
        var conditions: [P2PKSpendingCondition] = []
        
        for proof in proofs {
            guard let condition = proof.getP2PKSpendingCondition() else {
                continue
            }
            
            if condition.signatureFlag == .sigAll {
                requiresAllSignatures = true
            }
            
            conditions.append(condition)
            
            if !validateProofSignatures(proof: proof, condition: condition) {
                return false
            }
        }
        
        if requiresAllSignatures && !blindedMessages.isEmpty {
            guard let firstCondition = conditions.first else {
                return false
            }
            
            for blindedMessage in blindedMessages {
                if !validateBlindedMessageSignatures(blindedMessage: blindedMessage, condition: firstCondition) {
                    return false
                }
            }
        }
        
        return true
    }
}

