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
} 
