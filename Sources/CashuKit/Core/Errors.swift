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
}

// MARK: - HTTP Error Response (NUT-00 Specification)

/// HTTP error response structure as defined in NUT-00
/// Used when mints respond with HTTP status code 400 and error details
public struct CashuHTTPError: Codable, Error {
    /// Error message
    public let detail: String
    /// Error code
    public let code: Int
    
    public init(detail: String, code: Int) {
        self.detail = detail
        self.code = code
    }
} 
