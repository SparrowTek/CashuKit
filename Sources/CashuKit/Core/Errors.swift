//
//  Errors.swift
//  CashuKit
//
//  Shared error types for CashuKit
//

import Foundation

/// Categories of errors for better handling
public enum CashuErrorCategory: String, Sendable {
    case cryptographic = "Cryptographic"
    case network = "Network"
    case validation = "Validation"
    case wallet = "Wallet"
    case storage = "Storage"
    case `protocol` = "Protocol"
}

/// Errors that can occur during Cashu operations
public enum CashuError: Error, Sendable {
    // Core cryptographic errors
    case invalidPoint
    case invalidSecretLength
    case hashToCurveFailed
    case blindingFailed
    case unblindingFailed
    case verificationFailed
    case invalidHexString
    case keyGenerationFailed
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
    case walletNotInitializedWithMnemonic
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
    case unsupportedVersion
    case missingBlindingFactor
    
    // NUT-13 specific errors
    case invalidMnemonic
    case invalidSecret
    case invalidSignature(String)
    case mismatchedArrayLengths
}

// MARK: - HTTP Error Response (NUT-00 Specification)

/// HTTP error response structure as defined in NUT-00
/// Used when mints respond with HTTP status code 400 and error details
public struct CashuHTTPError: CashuCodabale, Error, Sendable {
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

// MARK: - Error Category

extension CashuError {
    /// The category of this error
    public var category: CashuErrorCategory {
        switch self {
        case .invalidPoint, .invalidSecretLength, .hashToCurveFailed, .blindingFailed,
             .unblindingFailed, .verificationFailed, .invalidHexString, .keyGenerationFailed,
             .invalidSignature, .domainSeperator, .missingBlindingFactor:
            return .cryptographic
            
        case .networkError, .invalidMintURL, .mintUnavailable, .invalidResponse,
             .rateLimitExceeded, .httpError:
            return .network
            
        case .invalidTokenFormat, .serializationFailed, .deserializationFailed,
             .validationFailed, .invalidAmount, .amountTooLarge, .amountTooSmall,
             .missingRequiredField, .invalidTokenStructure:
            return .validation
            
        case .walletNotInitialized, .walletAlreadyInitialized, .walletNotInitializedWithMnemonic,
             .invalidProofSet, .proofAlreadySpent, .proofNotFound, .balanceInsufficient, 
             .noSpendableProofs, .invalidWalletState, .tokenExpired, .tokenAlreadyUsed:
            return .wallet
            
        case .storageError:
            return .storage
            
        case .nutNotImplemented, .invalidNutVersion, .invalidKeysetID, .insufficientFunds,
             .syncRequired, .operationTimeout, .operationCancelled, .invalidMintConfiguration,
             .keysetNotFound, .keysetExpired, .unsupportedOperation, .concurrencyError,
             .unsupportedVersion, .invalidMnemonic, .invalidSecret,
             .invalidSignature, .mismatchedArrayLengths:
            return .`protocol`
        }
    }
    
    /// Whether this error is retryable
    public var isRetryable: Bool {
        switch self {
        case .networkError, .mintUnavailable, .rateLimitExceeded, .operationTimeout:
            return true
        case .httpError(_, let code):
            return code >= 500 || code == 429
        default:
            return false
        }
    }
    
    /// Error code for debugging
    public var code: String {
        let mirror = Mirror(reflecting: self)
        return "CASHU_\(String(describing: mirror.children.first?.label ?? "UNKNOWN").uppercased())"
    }
}

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
        case .unsupportedVersion:
            return "Unsupported version"
        case .missingBlindingFactor:
            return "Missing blinding factor for DLEQ proof verification"
        case .walletNotInitializedWithMnemonic:
            return "Wallet was not initialized with a mnemonic phrase"
        case .invalidMnemonic:
            return "Invalid mnemonic phrase"
        case .invalidSecret:
            return "Invalid secret"
        case .invalidSignature(let message):
            return "Invalid signature: \(message)"
        case .mismatchedArrayLengths:
            return "Mismatched array lengths"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        // Cryptographic errors
        case .invalidSecretLength:
            return "Ensure the secret has the correct length for the cryptographic operation"
        case .hashToCurveFailed:
            return "Verify the input data is properly formatted"
        case .verificationFailed:
            return "Ensure you're using the correct keyset and the proof hasn't been tampered with"
        case .invalidHexString:
            return "Provide a valid hexadecimal string (0-9, A-F)"
            
        // Network errors
        case .networkError:
            return "Check your network connection and try again"
        case .mintUnavailable:
            return "Try again later or use a different mint"
        case .rateLimitExceeded:
            return "Wait a moment before trying again"
        case .invalidMintURL:
            return "Verify the mint URL is correct and includes the protocol (https://)"
        case .httpError(_, let code) where code == 429:
            return "You're making too many requests. Please wait before trying again"
        case .httpError(_, let code) where code >= 500:
            return "The mint is experiencing issues. Try again later"
            
        // Validation errors
        case .invalidTokenFormat:
            return "Ensure the token follows the Cashu token format specification"
        case .validationFailed:
            return "Check that all required fields are present and properly formatted"
        case .amountTooLarge:
            return "Use a smaller amount or split into multiple transactions"
        case .amountTooSmall:
            return "Use a larger amount that meets the minimum requirement"
            
        // Wallet errors
        case .walletNotInitialized:
            return "Initialize the wallet before performing operations"
        case .syncRequired:
            return "Sync the wallet with the mint to get the latest state"
        case .balanceInsufficient:
            return "Add more funds to your wallet or use a smaller amount"
        case .keysetExpired:
            return "Sync the wallet to get updated keysets from the mint"
        case .tokenExpired:
            return "Request a new token as this one has expired"
        case .operationTimeout:
            return "Check your connection and try the operation again"
        case .proofAlreadySpent:
            return "This proof has been used. Sync your wallet to update your balance"
        case .noSpendableProofs:
            return "Consolidate your proofs or add more funds to your wallet"
        case .unsupportedVersion:
            return "Update your wallet software to support this version"
            
        default:
            return nil
        }
    }
    
    public var failureReason: String? {
        switch self {
        // Cryptographic errors
        case .blindingFailed:
            return "The blinding factor could not be applied to the message"
        case .unblindingFailed:
            return "The blind signature could not be converted to a valid signature"
        case .keyGenerationFailed:
            return "Cryptographic keys could not be generated"
            
        // Network errors
        case .networkError:
            return "Network communication failed"
        case .mintUnavailable:
            return "Mint server is not responding"
        case .httpError(_, let code) where code == 404:
            return "The requested endpoint does not exist"
        case .httpError(_, let code) where code == 401:
            return "Authentication failed or required"
            
        // Validation errors
        case .invalidTokenFormat:
            return "Token format does not match expected structure"
        case .missingRequiredField:
            return "A required field is not present in the data"
            
        // Wallet errors
        case .walletNotInitialized:
            return "Wallet operations require initialization"
        case .balanceInsufficient:
            return "Not enough funds available for this operation"
        case .proofAlreadySpent:
            return "Proof has already been redeemed at the mint"
        case .keysetNotFound:
            return "The mint's signing keys are not available"
        case .invalidWalletState:
            return "The wallet is in an inconsistent state"
            
        default:
            return nil
        }
    }
    
    /// User info dictionary for NSError bridging
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [:]
        
        if let description = errorDescription {
            userInfo[NSLocalizedDescriptionKey] = description
        }
        
        if let reason = failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason
        }
        
        if let suggestion = recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = suggestion
        }
        
        userInfo["category"] = category.rawValue
        userInfo["code"] = code
        userInfo["isRetryable"] = isRetryable
        
        return userInfo
    }
}
