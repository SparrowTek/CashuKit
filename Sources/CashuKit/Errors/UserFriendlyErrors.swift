//
//  UserFriendlyErrors.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

// MARK: - Error Recovery Suggestion

public struct ErrorRecoverySuggestion: Sendable {
    public let title: String
    public let message: String
    public let actions: [RecoveryAction]
    
    public init(title: String, message: String, actions: [RecoveryAction]) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}

public struct RecoveryAction: Sendable {
    public let title: String
    public let handler: (@Sendable () async throws -> Void)?
    
    public init(title: String, handler: (@Sendable () async throws -> Void)? = nil) {
        self.title = title
        self.handler = handler
    }
}

// MARK: - User-Friendly Error Protocol

public protocol UserFriendlyError: Error {
    var userMessage: String { get }
    var technicalDetails: String { get }
    var errorRecoverySuggestion: ErrorRecoverySuggestion? { get }
}

// MARK: - CashuError User-Friendly Extensions

extension CashuError: UserFriendlyError {
    public var userMessage: String {
        switch self {
        // Network errors
        case .networkError:
            return "Unable to connect to the mint. Please check your internet connection."
        case .mintUnavailable:
            return "The mint is currently unavailable. Please try again later."
        case .connectionFailed:
            return "Connection to the mint failed. Please check your network settings."
            
        // Token errors
        case .invalidToken:
            return "The token is invalid or corrupted. Please check the token and try again."
        case .tokenAlreadySpent:
            return "This token has already been spent and cannot be used again."
        case .invalidProof:
            return "The proof is invalid. The token may be corrupted."
        case .tokenNotFound:
            return "Token not found. It may have been deleted or never existed."
            
        // Balance errors
        case .balanceInsufficient:
            return "Insufficient balance for this operation. Please add more funds."
        case .amountTooSmall:
            return "The amount is too small for this operation."
        case .amountTooLarge:
            return "The amount exceeds the maximum allowed limit."
            
        // Authentication errors are handled in NUT22.swift extensions
            
        // Quote errors
        case .quotePending:
            return "The payment is still being processed. Please wait a moment."
        case .quoteExpired:
            return "The quote has expired. Please request a new one."
        case .quoteNotFound:
            return "Quote not found. It may have expired or been cancelled."
            
        // Keyset errors
        case .keysetNotFound:
            return "The required keyset was not found. Please refresh the mint information."
        case .invalidKeysetID:
            return "Invalid keyset identifier. Please contact support."
        case .keysetInactive:
            return "The keyset is no longer active. Please refresh your wallet."
            
        // Cryptographic errors
        case .keyGenerationFailed:
            return "Failed to generate secure keys. Please try again."
        case .blindingFailed:
            return "Failed to process the transaction securely. Please try again."
        case .invalidSignature(_):
            return "Invalid signature detected. The token may be corrupted."
            
        // Wallet errors
        case .walletNotInitialized:
            return "The wallet needs to be initialized before use."
        case .invalidMnemonic:
            return "The recovery phrase is invalid. Please check for typos."
        case .invalidDerivationPath:
            return "Invalid wallet derivation path. Please use standard paths."
            
        // General errors
        case .invalidSecret:
            return "Invalid secret. The token cannot be processed."
        case .invalidAmount:
            return "Invalid amount specified. Please enter a valid amount."
        case .invalidMintURL:
            return "Invalid mint URL. Please check the address."
        case .invalidUnit:
            return "The selected unit is not supported by this mint."
        case .invalidDenomination:
            return "Invalid denomination. Please use standard denominations."
        case .mismatchedArrayLengths:
            return "Data inconsistency detected. Please try again."
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        case .notImplemented:
            return "This feature is not yet available."
        case .invalidState(let state):
            return "The wallet is in an invalid state: \(state)"
        case .serializationError(_):
            return "Failed to process the token data. It may be corrupted."
        case .jsonEncodingError, .jsonDecodingError:
            return "Failed to process data. Please try again."
        case .hexDecodingError:
            return "Failed to decode data. The token may be corrupted."
        case .base64DecodingError:
            return "Failed to decode token. Please check the token format."
        case .unhandledError(let status):
            return "An system error occurred (code: \(status))."
            
        // Fallback for any cases not explicitly handled
        default:
            return "An error occurred. Please try again."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .networkError(let details):
            return "Network error: \(details)"
        case .invalidSignature(let details):
            return "Signature validation failed: \(details)"
        case .serializationError(let details):
            return "Serialization failed: \(details)"
        case .invalidState(let state):
            return "Invalid state: \(state)"
        case .unhandledError(let status):
            return "System error code: \(status)"
        default:
            return String(describing: self)
        }
    }
    
    public var errorRecoverySuggestion: ErrorRecoverySuggestion? {
        switch self {
        case .networkError, .mintUnavailable, .connectionFailed:
            return ErrorRecoverySuggestion(
                title: "Connection Problem",
                message: "There was a problem connecting to the mint.",
                actions: [
                    RecoveryAction(title: "Check Internet Connection"),
                    RecoveryAction(title: "Try Again Later"),
                    RecoveryAction(title: "Contact Support")
                ]
            )
            
        case .balanceInsufficient:
            return ErrorRecoverySuggestion(
                title: "Insufficient Funds",
                message: "You don't have enough balance for this transaction.",
                actions: [
                    RecoveryAction(title: "Add Funds"),
                    RecoveryAction(title: "Use Smaller Amount"),
                    RecoveryAction(title: "Check Balance")
                ]
            )
            
        case .tokenAlreadySpent:
            return ErrorRecoverySuggestion(
                title: "Token Already Used",
                message: "This token has already been spent and cannot be reused.",
                actions: [
                    RecoveryAction(title: "Delete Token"),
                    RecoveryAction(title: "Request New Token")
                ]
            )
            
        case .quotePending:
            return ErrorRecoverySuggestion(
                title: "Payment Processing",
                message: "Your payment is still being processed.",
                actions: [
                    RecoveryAction(title: "Wait and Retry"),
                    RecoveryAction(title: "Check Status"),
                    RecoveryAction(title: "Cancel Payment")
                ]
            )
            
        case .quoteExpired:
            return ErrorRecoverySuggestion(
                title: "Quote Expired",
                message: "The payment quote has expired.",
                actions: [
                    RecoveryAction(title: "Request New Quote"),
                    RecoveryAction(title: "Try Again")
                ]
            )
            
        case .walletNotInitialized:
            return ErrorRecoverySuggestion(
                title: "Wallet Not Ready",
                message: "The wallet needs to be set up before use.",
                actions: [
                    RecoveryAction(title: "Initialize Wallet"),
                    RecoveryAction(title: "Restore from Backup")
                ]
            )
            
        case .invalidMnemonic:
            return ErrorRecoverySuggestion(
                title: "Invalid Recovery Phrase",
                message: "The recovery phrase you entered is not valid.",
                actions: [
                    RecoveryAction(title: "Check for Typos"),
                    RecoveryAction(title: "Verify Word Order"),
                    RecoveryAction(title: "Use Different Phrase")
                ]
            )
            
        default:
            return nil
        }
    }
}

// MARK: - Error Message Formatter

public struct ErrorMessageFormatter {
    public static func format(
        error: any Error,
        includeDetails: Bool = false,
        includeRecovery: Bool = true
    ) -> String {
        if let userError = error as? any UserFriendlyError {
            var message = userError.userMessage
            
            if includeDetails {
                message += "\n\nDetails: \(userError.technicalDetails)"
            }
            
            if includeRecovery, let recovery = userError.errorRecoverySuggestion {
                message += "\n\n\(recovery.message)"
                if !recovery.actions.isEmpty {
                    message += "\n\nYou can:"
                    for action in recovery.actions {
                        message += "\n• \(action.title)"
                    }
                }
            }
            
            return message
        }
        
        // Fallback for non-CashuError
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
    
    public static func shortMessage(for error: any Error) -> String {
        if let userError = error as? any UserFriendlyError {
            return userError.userMessage
        }
        return error.localizedDescription
    }
    
    public static func detailedMessage(for error: any Error) -> String {
        return format(error: error, includeDetails: true, includeRecovery: true)
    }
}

// MARK: - Error Analytics Helper

public struct ErrorAnalytics {
    public static func logError(
        _ error: any Error,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorCategory = (error as? CashuError)?.category.rawValue ?? "unknown"
        let userMessage = ErrorMessageFormatter.shortMessage(for: error)
        
        var logContext = context
        logContext["error_category"] = errorCategory
        logContext["user_message"] = userMessage
        logContext["file"] = URL(fileURLWithPath: file).lastPathComponent
        logContext["function"] = function
        logContext["line"] = line
        
        logger.error("Error occurred: \(error) - Context: \(logContext)", file: file, function: function, line: line)
    }
}
