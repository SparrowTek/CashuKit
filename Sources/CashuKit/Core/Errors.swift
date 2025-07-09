//
//  Errors.swift
//  CashuKit
//
//  Shared error types for CashuKit
//

import Foundation

/// Errors that can occur during Cashu operations
public enum CashuError: Error {
    // Core cryptographic errors
    case invalidPoint
    case invalidSecretLength
    case hashToCurveFailed
    case blindingFailed
    case unblindingFailed
    case verificationFailed
    case invalidHexString
    case keyGenerationFailed
    case invalidSignature
    case domainSeperator
    
    // Network and API errors
    case networkError(String)
    case invalidMintURL
    case mintUnavailable
    case invalidResponse
    case rateLimitExceeded
    case insufficientFunds
    
    // Token and serialization errors
    case invalidTokenFormat
    case serializationFailed
    case deserializationFailed
    case validationFailed
    
    // NUT-specific errors
    case nutNotImplemented(String)
    case invalidNutVersion(String)
    case invalidKeysetID
    
    // HTTP API errors (following NUT-00 error format)
    case httpError(detail: String, code: Int)
    
    // Wallet-specific errors
    case walletNotInitialized
    case walletAlreadyInitialized
    case invalidProofSet
    case proofAlreadySpent
    case proofNotFound
    case invalidAmount
    case amountTooLarge
    case amountTooSmall
    case balanceInsufficient
    case noSpendableProofs
    case invalidWalletState
    case storageError(String)
    case syncRequired
    case operationTimeout
    case operationCancelled
    case invalidMintConfiguration
    case keysetNotFound
    case keysetExpired
    case tokenExpired
    case tokenAlreadyUsed
    case invalidTokenStructure
    case missingRequiredField(String)
    case unsupportedOperation(String)
    case concurrencyError(String)
}

// MARK: - HTTP Error Response (NUT-00 Specification)

/// HTTP error response structure as defined in NUT-00
/// Used when mints respond with HTTP status code 400 and error details
public struct CashuHTTPError: CashuCodabale, Error {
    /// Error message
    public let detail: String
    /// Error code
    public let code: Int
    
    public init(detail: String, code: Int) {
        self.detail = detail
        self.code = code
    }
}

// MARK: - Error Extensions

extension CashuError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        // Core cryptographic errors
        case .invalidPoint:
            return "Invalid elliptic curve point"
        case .invalidSecretLength:
            return "Invalid secret length"
        case .hashToCurveFailed:
            return "Hash-to-curve operation failed"
        case .blindingFailed:
            return "Blinding operation failed"
        case .unblindingFailed:
            return "Unblinding operation failed"
        case .verificationFailed:
            return "Signature verification failed"
        case .invalidHexString:
            return "Invalid hexadecimal string"
        case .keyGenerationFailed:
            return "Key generation failed"
        case .invalidSignature:
            return "Invalid signature"
        case .domainSeperator:
            return "Domain separator error"
            
        // Network and API errors
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidMintURL:
            return "Invalid mint URL"
        case .mintUnavailable:
            return "Mint is unavailable"
        case .invalidResponse:
            return "Invalid response from mint"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .insufficientFunds:
            return "Insufficient funds"
            
        // Token and serialization errors
        case .invalidTokenFormat:
            return "Invalid token format"
        case .serializationFailed:
            return "Serialization failed"
        case .deserializationFailed:
            return "Deserialization failed"
        case .validationFailed:
            return "Validation failed"
            
        // NUT-specific errors
        case .nutNotImplemented(let nut):
            return "NUT \(nut) not implemented"
        case .invalidNutVersion(let version):
            return "Invalid NUT version: \(version)"
        case .invalidKeysetID:
            return "Invalid keyset ID"
            
        // HTTP API errors
        case .httpError(let detail, let code):
            return "HTTP error \(code): \(detail)"
            
        // Wallet-specific errors
        case .walletNotInitialized:
            return "Wallet not initialized"
        case .walletAlreadyInitialized:
            return "Wallet already initialized"
        case .invalidProofSet:
            return "Invalid proof set"
        case .proofAlreadySpent:
            return "Proof already spent"
        case .proofNotFound:
            return "Proof not found"
        case .invalidAmount:
            return "Invalid amount"
        case .amountTooLarge:
            return "Amount too large"
        case .amountTooSmall:
            return "Amount too small"
        case .balanceInsufficient:
            return "Insufficient balance"
        case .noSpendableProofs:
            return "No spendable proofs available"
        case .invalidWalletState:
            return "Invalid wallet state"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .syncRequired:
            return "Wallet sync required"
        case .operationTimeout:
            return "Operation timed out"
        case .operationCancelled:
            return "Operation cancelled"
        case .invalidMintConfiguration:
            return "Invalid mint configuration"
        case .keysetNotFound:
            return "Keyset not found"
        case .keysetExpired:
            return "Keyset expired"
        case .tokenExpired:
            return "Token expired"
        case .tokenAlreadyUsed:
            return "Token already used"
        case .invalidTokenStructure:
            return "Invalid token structure"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .concurrencyError(let message):
            return "Concurrency error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .walletNotInitialized:
            return "Initialize the wallet before performing operations"
        case .syncRequired:
            return "Sync the wallet with the mint"
        case .balanceInsufficient:
            return "Add more funds to your wallet"
        case .networkError:
            return "Check your network connection and try again"
        case .mintUnavailable:
            return "Try again later or use a different mint"
        case .rateLimitExceeded:
            return "Wait a moment before trying again"
        case .invalidMintURL:
            return "Verify the mint URL is correct"
        case .keysetExpired:
            return "Sync the wallet to get updated keysets"
        case .tokenExpired:
            return "Use a valid, non-expired token"
        case .operationTimeout:
            return "Try the operation again"
        default:
            return nil
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .walletNotInitialized:
            return "Wallet operations require initialization"
        case .balanceInsufficient:
            return "Not enough funds available"
        case .networkError:
            return "Network communication failed"
        case .mintUnavailable:
            return "Mint server is not responding"
        case .invalidTokenFormat:
            return "Token format does not match expected structure"
        case .proofAlreadySpent:
            return "Proof has already been used"
        case .keysetNotFound:
            return "Required keyset is not available"
        default:
            return nil
        }
    }
}
