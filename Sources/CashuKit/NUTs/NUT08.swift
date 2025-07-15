//
//  NUT08.swift
//  CashuKit
//
//  NUT-08: Lightning fee return
//  https://github.com/cashubtc/nuts/blob/main/08.md
//

import Foundation
@preconcurrency import P256K

// MARK: - NUT-08: Lightning fee return

/// NUT-08: Lightning fee return
/// Handles overpaid Lightning fees through blank outputs

// MARK: - Core Types

/// Represents a blank output for fee return
/// Blank outputs are blinded messages with undetermined values
public struct BlankOutput: Sendable {
    public let blindedMessage: BlindedMessage
    public let blindingData: WalletBlindingData
    
    public init(blindedMessage: BlindedMessage, blindingData: WalletBlindingData) {
        self.blindedMessage = blindedMessage
        self.blindingData = blindingData
    }
}

/// Result of fee return processing
public struct FeeReturnResult: Sendable {
    public let returnedAmount: Int
    public let returnedProofs: [Proof]
    public let blankOutputsUsed: Int
    public let blankOutputsProvided: Int
    
    public init(returnedAmount: Int, returnedProofs: [Proof], blankOutputsUsed: Int, blankOutputsProvided: Int) {
        self.returnedAmount = returnedAmount
        self.returnedProofs = returnedProofs
        self.blankOutputsUsed = blankOutputsUsed
        self.blankOutputsProvided = blankOutputsProvided
    }
    
    /// Whether any fees were returned
    public var hasReturn: Bool {
        return returnedAmount > 0
    }
    
    /// Efficiency of blank output usage
    public var outputEfficiency: Double {
        guard blankOutputsProvided > 0 else { return 0.0 }
        return Double(blankOutputsUsed) / Double(blankOutputsProvided)
    }
}

/// Configuration for fee return handling
public struct FeeReturnConfiguration: Sendable {
    public let keysetID: String
    public let unit: String
    public let maxBlankOutputs: Int
    
    public init(keysetID: String, unit: String, maxBlankOutputs: Int = 64) {
        self.keysetID = keysetID
        self.unit = unit
        self.maxBlankOutputs = maxBlankOutputs
    }
}

// MARK: - Fee Return Calculator

/// Utility for calculating blank outputs needed for fee returns
public struct FeeReturnCalculator: Sendable {
    
    /// Calculate the number of blank outputs needed for a fee reserve
    /// Formula: max(ceil(log2(fee_reserve)), 1) if fee_reserve > 0, else 0
    /// - Parameter feeReserve: The fee reserve amount in satoshis
    /// - Returns: Number of blank outputs needed
    public static func calculateBlankOutputCount(feeReserve: Int) -> Int {
        precondition(feeReserve >= 0, "Fee reserve can't be negative")
        
        if feeReserve == 0 {
            return 0
        }
        
        return max(Int(ceil(log2(Double(feeReserve)))), 1)
    }
    
    /// Decompose an amount into optimal denominations (powers of 2)
    /// - Parameter amount: Amount to decompose
    /// - Returns: Array of denominations that sum to the amount
    public static func decomposeToOptimalDenominations(_ amount: Int) -> [Int] {
        guard amount > 0 else { return [] }
        
        var denominations: [Int] = []
        var remaining = amount
        var power = 0
        
        while remaining > 0 {
            let denomination = 1 << power // 2^power
            if remaining & denomination != 0 {
                denominations.append(denomination)
                remaining -= denomination
            }
            power += 1
        }
        
        return denominations.sorted() // Privacy-preserving order (ascending)
    }
    
    /// Calculate optimal fee reserve for a payment amount
    /// - Parameters:
    ///   - amount: Payment amount
    ///   - estimatedFee: Estimated fee
    ///   - safetyMargin: Safety margin multiplier (default 2.0)
    /// - Returns: Recommended fee reserve
    public static func calculateOptimalFeeReserve(
        amount: Int, 
        estimatedFee: Int, 
        safetyMargin: Double = 2.0
    ) -> Int {
        guard estimatedFee > 0 else { return 0 }
        return Int(Double(estimatedFee) * safetyMargin)
    }
    
    /// Validate that blank outputs can handle the maximum possible fee return
    /// - Parameters:
    ///   - blankOutputCount: Number of blank outputs
    ///   - maxPossibleReturn: Maximum possible fee return
    /// - Returns: True if blank outputs are sufficient
    public static func validateBlankOutputCapacity(
        blankOutputCount: Int, 
        maxPossibleReturn: Int
    ) -> Bool {
        guard blankOutputCount > 0, maxPossibleReturn > 0 else { return true }
        
        // Maximum amount that can be represented with n blank outputs
        let maxRepresentable = (1 << blankOutputCount) - 1
        return maxRepresentable >= maxPossibleReturn
    }
    
    /// Calculate the efficiency of a fee return
    /// - Parameters:
    ///   - returnedAmount: Amount returned
    ///   - feeReserve: Original fee reserve
    /// - Returns: Efficiency ratio (0.0 to 1.0)
    public static func calculateReturnEfficiency(
        returnedAmount: Int, 
        feeReserve: Int
    ) -> Double {
        guard feeReserve > 0 else { return 0.0 }
        return Double(returnedAmount) / Double(feeReserve)
    }
}

// MARK: - Blank Output Generator

/// Generates blank outputs for fee returns
public struct BlankOutputGenerator {
    
    /// Generate blank outputs for a fee reserve
    /// - Parameters:
    ///   - count: Number of blank outputs to generate
    ///   - keysetID: Keyset ID to use
    /// - Returns: Array of blank outputs with their blinding data
    public static func generateBlankOutputs(
        count: Int, 
        keysetID: String
    ) async throws -> [BlankOutput] {
        guard count > 0 else { return [] }
        
        var blankOutputs: [BlankOutput] = []
        
        for _ in 0..<count {
            // Generate a random secret for the blank output
            let secret = CashuKeyUtils.generateRandomSecret()
            
            // Create blinding data
            let blindingData = try WalletBlindingData(secret: secret)
            
            // Create blinded message with placeholder amount (will be set by mint)
            let blindedMessage = BlindedMessage(
                amount: 1, // Placeholder amount - ignored by mint in NUT-08
                id: keysetID,
                B_: blindingData.blindedMessage.dataRepresentation.hexString
            )
            
            blankOutputs.append(BlankOutput(
                blindedMessage: blindedMessage,
                blindingData: blindingData
            ))
        }
        
        return blankOutputs
    }
    
    /// Process returned change signatures into proofs
    /// - Parameters:
    ///   - changeSignatures: Blind signatures returned by mint
    ///   - blankOutputs: Original blank outputs provided
    ///   - mintPublicKeys: Mint public keys for unblinding
    /// - Returns: Fee return result with unblinded proofs
    public static func processChangeSignatures(
        changeSignatures: [BlindSignature],
        blankOutputs: [BlankOutput],
        mintPublicKeys: [String: Data]
    ) throws -> FeeReturnResult {
        var returnedProofs: [Proof] = []
        var totalReturnedAmount = 0
        
        // Process each returned signature
        for (index, signature) in changeSignatures.enumerated() {
            guard index < blankOutputs.count else {
                throw NUT08Error.invalidChangeSignatureOrder(
                    "Change signature index \(index) exceeds blank outputs count \(blankOutputs.count)"
                )
            }
            
            let blankOutput = blankOutputs[index]
            
            // Get mint public key for this amount
            guard let mintPublicKeyData = mintPublicKeys[String(signature.amount)] else {
                throw NUT08Error.missingMintPublicKey("No mint public key for amount \(signature.amount)")
            }
            
            let mintPublicKey = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: mintPublicKeyData, 
                format: .compressed
            )
            
            // Unblind the signature
            let unblindedToken = try Wallet.unblindSignature(
                blindedSignature: Data(hexString: signature.C_)!,
                blindingData: blankOutput.blindingData,
                mintPublicKey: mintPublicKey
            )
            
            // Create proof
            let proof = Proof(
                amount: signature.amount,
                id: signature.id,
                secret: unblindedToken.secret,
                C: unblindedToken.signature.hexString
            )
            
            returnedProofs.append(proof)
            totalReturnedAmount += signature.amount
        }
        
        return FeeReturnResult(
            returnedAmount: totalReturnedAmount,
            returnedProofs: returnedProofs,
            blankOutputsUsed: changeSignatures.count,
            blankOutputsProvided: blankOutputs.count
        )
    }
}

// MARK: - Enhanced Melt Request with Blank Outputs

/// Extended melt request that includes blank outputs for fee return (NUT-08)
public struct PostMeltRequestWithFeeReturn: CashuCodabale {
    public let quote: String
    public let inputs: [Proof]
    public let outputs: [BlindedMessage]?
    
    public init(quote: String, inputs: [Proof], outputs: [BlindedMessage]? = nil) {
        self.quote = quote
        self.inputs = inputs
        self.outputs = outputs
    }
    
    /// Create request with blank outputs for fee return
    public init(
        quote: String, 
        inputs: [Proof], 
        blankOutputs: [BlankOutput]
    ) {
        self.quote = quote
        self.inputs = inputs
        self.outputs = blankOutputs.map { $0.blindedMessage }
    }
    
    /// Validate the melt request structure
    public func validate() -> Bool {
        guard !quote.isEmpty, !inputs.isEmpty else { return false }
        
        // Basic validation for inputs
        for input in inputs {
            guard input.amount > 0,
                  !input.id.isEmpty,
                  !input.secret.isEmpty,
                  !input.C.isEmpty else {
                return false
            }
        }
        
        // Validate outputs if provided
        if let outputs = outputs {
            for output in outputs {
                guard let outputId = output.id, !outputId.isEmpty,
                      !output.B_.isEmpty else {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Get total input amount
    public var totalInputAmount: Int {
        return inputs.reduce(0) { $0 + $1.amount }
    }
    
    /// Number of blank outputs provided
    public var blankOutputCount: Int {
        return outputs?.count ?? 0
    }
    
    /// Whether this request supports fee return
    public var supportsFeeReturn: Bool {
        return outputs != nil && !outputs!.isEmpty
    }
}

// MARK: - Error Types

/// Errors specific to NUT-08 operations
public enum NUT08Error: Error, LocalizedError, Sendable {
    case invalidFeeReserve(String)
    case blankOutputGenerationFailed(String)
    case invalidChangeSignatureOrder(String)
    case missingMintPublicKey(String)
    case feeReturnProcessingFailed(String)
    case insufficientBlankOutputs(required: Int, provided: Int)
    case invalidBlankOutputAmount(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidFeeReserve(let reason):
            return "Invalid fee reserve: \(reason)"
        case .blankOutputGenerationFailed(let reason):
            return "Blank output generation failed: \(reason)"
        case .invalidChangeSignatureOrder(let reason):
            return "Invalid change signature order: \(reason)"
        case .missingMintPublicKey(let reason):
            return "Missing mint public key: \(reason)"
        case .feeReturnProcessingFailed(let reason):
            return "Fee return processing failed: \(reason)"
        case .insufficientBlankOutputs(let required, let provided):
            return "Insufficient blank outputs: required \(required), provided \(provided)"
        case .invalidBlankOutputAmount(let reason):
            return "Invalid blank output amount: \(reason)"
        }
    }
}

// MARK: - Fee Return Statistics

/// Statistics for tracking fee return efficiency
public struct FeeReturnStatistics: Sendable {
    public let totalPayments: Int
    public let paymentsWithFeeReturn: Int
    public let totalFeeReserve: Int
    public let totalFeesReturned: Int
    public let averageReturnEfficiency: Double
    public let blankOutputUtilization: Double
    
    public init(
        totalPayments: Int,
        paymentsWithFeeReturn: Int,
        totalFeeReserve: Int,
        totalFeesReturned: Int,
        averageReturnEfficiency: Double,
        blankOutputUtilization: Double
    ) {
        self.totalPayments = totalPayments
        self.paymentsWithFeeReturn = paymentsWithFeeReturn
        self.totalFeeReserve = totalFeeReserve
        self.totalFeesReturned = totalFeesReturned
        self.averageReturnEfficiency = averageReturnEfficiency
        self.blankOutputUtilization = blankOutputUtilization
    }
    
    /// Percentage of payments that had fee returns
    public var feeReturnRate: Double {
        guard totalPayments > 0 else { return 0.0 }
        return Double(paymentsWithFeeReturn) / Double(totalPayments)
    }
    
    /// Overall efficiency of the fee return system
    public var overallEfficiency: Double {
        guard totalFeeReserve > 0 else { return 0.0 }
        return Double(totalFeesReturned) / Double(totalFeeReserve)
    }
}

// MARK: - Convenience Extensions

extension BlindedMessage {
    /// Create a blank output blinded message
    /// - Parameters:
    ///   - keysetID: Keyset ID
    ///   - blindingData: Wallet blinding data
    /// - Returns: Blinded message for blank output
    public static func createBlankOutput(
        keysetID: String, 
        blindingData: WalletBlindingData
    ) -> BlindedMessage {
        return BlindedMessage(
            amount: 1, // Placeholder amount for blank output
            id: keysetID,
            B_: blindingData.blindedMessage.dataRepresentation.hexString
        )
    }
}