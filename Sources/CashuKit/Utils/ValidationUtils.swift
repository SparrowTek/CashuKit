//
//  ValidationUtils.swift
//  CashuKit
//
//  Input validation utilities for wallet operations
//

import Foundation

// MARK: - Validation Protocols

/// Protocol for validatable objects
public protocol Validatable {
    /// Validate the object
    /// - Returns: True if valid, false otherwise
    func isValid() -> Bool
    
    /// Get validation errors
    /// - Returns: Array of validation errors
    func validationErrors() -> [String]
}

// MARK: - Validation Utilities

/// Utility class for common validation operations
public struct ValidationUtils: Sendable {
    
    // MARK: - Amount Validation
    
    /// Validate amount value
    /// - Parameters:
    ///   - amount: Amount to validate
    ///   - min: Minimum allowed value (default: 1)
    ///   - max: Maximum allowed value (default: nil)
    /// - Returns: Validation result
    public static func validateAmount(
        _ amount: Int,
        min: Int = 1,
        max: Int? = nil
    ) -> ValidationResult {
        var errors: [String] = []
        
        if amount < min {
            errors.append("Amount must be at least \(min)")
        }
        
        if let max = max, amount > max {
            errors.append("Amount must be at most \(max)")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate amount is positive
    /// - Parameter amount: Amount to validate
    /// - Returns: True if positive, false otherwise
    public static func isPositiveAmount(_ amount: Int) -> Bool {
        return amount > 0
    }
    
    // MARK: - URL Validation
    
    /// Validate mint URL
    /// - Parameter url: URL string to validate
    /// - Returns: Validation result
    public static func validateMintURL(_ url: String) -> ValidationResult {
        var errors: [String] = []
        
        // Check if empty
        if url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("URL cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Check URL format
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var urlToCheck = trimmedURL
        
        // Add scheme if missing
        if !urlToCheck.contains("://") {
            urlToCheck = "https://" + urlToCheck
        }
        
        guard let url = URL(string: urlToCheck) else {
            errors.append("Invalid URL format")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Check scheme
        if let scheme = url.scheme {
            if !["http", "https"].contains(scheme.lowercased()) {
                errors.append("URL must use HTTP or HTTPS scheme")
            }
        } else {
            errors.append("URL must use HTTP or HTTPS scheme")
        }
        
        // Check host
        if let host = url.host {
            if host.isEmpty {
                errors.append("URL must have a valid host")
            }
            // Check if host contains valid characters and structure
            if host.contains(" ") || (!host.contains(".") && !host.lowercased().contains("localhost")) {
                errors.append("URL must have a valid host")
            }
        } else {
            errors.append("URL must have a valid host")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Normalize mint URL (add scheme, remove trailing slash)
    /// - Parameter url: URL to normalize
    /// - Returns: Normalized URL
    /// - Throws: CashuError.invalidMintURL if URL is invalid
    public static func normalizeMintURL(_ url: String) throws -> String {
        let validation = validateMintURL(url)
        guard validation.isValid else {
            throw CashuError.invalidMintURL
        }
        
        var normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme
        if !normalizedURL.contains("://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        // Remove trailing slash
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        
        return normalizedURL
    }
    
    // MARK: - String Validation
    
    /// Validate hex string
    /// - Parameter hexString: Hex string to validate
    /// - Returns: Validation result
    public static func validateHexString(_ hexString: String) -> ValidationResult {
        var errors: [String] = []
        
        if hexString.isEmpty {
            errors.append("Hex string cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        let hexPattern = "^[0-9A-Fa-f]+$"
        do {
            let regex = try NSRegularExpression(pattern: hexPattern)
            let range = NSRange(location: 0, length: hexString.count)
            
            if regex.firstMatch(in: hexString, options: [], range: range) == nil {
                errors.append("Invalid hex string format")
            }
        } catch {
            errors.append("Failed to validate hex string format")
        }
        
        // Check even length (for proper byte representation)
        if hexString.count % 2 != 0 {
            errors.append("Hex string must have even length")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate non-empty string
    /// - Parameters:
    ///   - string: String to validate
    ///   - fieldName: Name of the field for error messages
    /// - Returns: Validation result
    public static func validateNonEmptyString(
        _ string: String,
        fieldName: String
    ) -> ValidationResult {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return ValidationResult(
                isValid: false,
                errors: ["\(fieldName) cannot be empty"]
            )
        }
        
        return ValidationResult(isValid: true, errors: [])
    }
    
    // MARK: - Proof Validation
    
    /// Validate proof structure
    /// - Parameter proof: Proof to validate
    /// - Returns: Validation result
    public static func validateProof(_ proof: Proof) -> ValidationResult {
        var errors: [String] = []
        
        // Validate amount
        let amountValidation = validateAmount(proof.amount)
        if !amountValidation.isValid {
            errors.append(contentsOf: amountValidation.errors)
        }
        
        // Validate required fields
        let secretValidation = validateNonEmptyString(proof.secret, fieldName: "secret")
        if !secretValidation.isValid {
            errors.append(contentsOf: secretValidation.errors)
        }
        
        let idValidation = validateNonEmptyString(proof.id, fieldName: "id")
        if !idValidation.isValid {
            errors.append(contentsOf: idValidation.errors)
        }
        
        let cValidation = validateHexString(proof.C)
        if !cValidation.isValid {
            errors.append("Invalid C value: \(cValidation.errors.joined(separator: ", "))")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate array of proofs
    /// - Parameter proofs: Proofs to validate
    /// - Returns: Validation result
    public static func validateProofs(_ proofs: [Proof]) -> ValidationResult {
        var errors: [String] = []
        
        if proofs.isEmpty {
            errors.append("Proof array cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        for (index, proof) in proofs.enumerated() {
            let proofValidation = validateProof(proof)
            if !proofValidation.isValid {
                errors.append("Proof at index \(index): \(proofValidation.errors.joined(separator: ", "))")
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Token Validation
    
    /// Validate Cashu token
    /// - Parameter token: Token to validate
    /// - Returns: Validation result
    public static func validateCashuToken(_ token: CashuToken) -> ValidationResult {
        var errors: [String] = []
        
        if token.token.isEmpty {
            errors.append("Token entries cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        for (index, entry) in token.token.enumerated() {
            let entryValidation = validateTokenEntry(entry)
            if !entryValidation.isValid {
                errors.append("Token entry at index \(index): \(entryValidation.errors.joined(separator: ", "))")
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate token entry
    /// - Parameter entry: Token entry to validate
    /// - Returns: Validation result
    public static func validateTokenEntry(_ entry: TokenEntry) -> ValidationResult {
        var errors: [String] = []
        
        // Validate mint URL
        let mintValidation = validateMintURL(entry.mint)
        if !mintValidation.isValid {
            errors.append("Invalid mint URL: \(mintValidation.errors.joined(separator: ", "))")
        }
        
        // Validate proofs
        let proofsValidation = validateProofs(entry.proofs)
        if !proofsValidation.isValid {
            errors.append("Invalid proofs: \(proofsValidation.errors.joined(separator: ", "))")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Payment Request Validation
    
    /// Validate Lightning payment request (basic validation)
    /// - Parameter paymentRequest: Payment request to validate
    /// - Returns: Validation result
    public static func validatePaymentRequest(_ paymentRequest: String) -> ValidationResult {
        var errors: [String] = []
        
        let trimmed = paymentRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            errors.append("Payment request cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Basic Lightning invoice validation
        if trimmed.lowercased().hasPrefix("ln") {
            // Lightning invoice format validation - very permissive
            // Just check that it starts with ln(bc|tb|bcrt) and has minimum length
            let lowerTrimmed = trimmed.lowercased()
            if !(lowerTrimmed.hasPrefix("lnbc") || lowerTrimmed.hasPrefix("lntb") || lowerTrimmed.hasPrefix("lnbcrt")) {
                errors.append("Invalid Lightning invoice format")
            } else if trimmed.count < 10 {
                // Minimum length check
                errors.append("Invalid Lightning invoice format")
            }
        } else {
            // If it doesn't start with "ln", it's not a valid Lightning invoice
            errors.append("Invalid Lightning invoice format")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Unit Validation
    
    /// Validate currency unit
    /// - Parameter unit: Unit to validate
    /// - Returns: Validation result
    public static func validateUnit(_ unit: String) -> ValidationResult {
        var errors: [String] = []
        
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            errors.append("Unit cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Check against supported units
        let supportedUnits = ["sat", "msat", "btc", "usd", "eur", "gbp", "jpy", "cad", "aud", "chf"]
        if !supportedUnits.contains(trimmed.lowercased()) {
            errors.append("Unsupported unit: \(trimmed)")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// MARK: - Validation Result

/// Result of a validation operation
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [String]
    
    public init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
    
    /// Get first error message
    public var firstError: String? {
        errors.first
    }
    
    /// Get all errors as a single string
    public var allErrors: String {
        errors.joined(separator: "; ")
    }
}

// MARK: - Validation Extensions

// Note: Extensions removed to avoid conflicts with existing methods

// MARK: - Validation Convenience Functions

/// Validate and throw if invalid
/// - Parameters:
///   - value: Value to validate
///   - validator: Validation function
///   - error: Error to throw if validation fails
/// - Throws: The provided error if validation fails
public func validateAndThrow<T>(
    _ value: T,
    validator: (T) -> ValidationResult,
    error: CashuError
) throws {
    let result = validator(value)
    if !result.isValid {
        throw error
    }
}

/// Validate amount and throw if invalid
/// - Parameters:
///   - amount: Amount to validate
///   - min: Minimum value
///   - max: Maximum value
/// - Throws: CashuError.invalidAmount if validation fails
public func validateAmountAndThrow(
    _ amount: Int,
    min: Int = 1,
    max: Int? = nil
) throws {
    let result = ValidationUtils.validateAmount(amount, min: min, max: max)
    if !result.isValid {
        throw CashuError.invalidAmount
    }
}