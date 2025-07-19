//
//  NUTValidation.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

/// Centralized validation utilities for NUT protocol compliance
public struct NUTValidation: Sendable {
    
    // MARK: - Amount Validation
    
    /// Validate amount for Cashu operations
    /// - Parameters:
    ///   - amount: Amount to validate
    ///   - maxAmount: Maximum allowed amount (optional)
    /// - Returns: Validation result
    public static func validateAmount(_ amount: Int, maxAmount: Int? = nil) -> ValidationResult {
        var errors: [String] = []
        
        // Amount must be positive
        if amount <= 0 {
            errors.append("Amount must be positive")
        }
        
        // Check maximum amount
        if let maxAmount = maxAmount, amount > maxAmount {
            errors.append("Amount \(amount) exceeds maximum of \(maxAmount)")
        }
        
        // Check for reasonable bounds (prevent overflow in calculations)
        if amount > 2_100_000_000_000_000 { // 21M BTC in satoshis
            errors.append("Amount exceeds reasonable maximum")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Quote Validation
    
    /// Validate Lightning invoice format
    /// - Parameter invoice: Lightning invoice string
    /// - Returns: Validation result
    public static func validateLightningInvoice(_ invoice: String) -> ValidationResult {
        var errors: [String] = []
        
        let trimmed = invoice.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            errors.append("Invoice cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Lightning invoice format validation
        let lowercased = trimmed.lowercased()
        
        // Must start with lnbc, lntb, or lnbcrt
        if !lowercased.hasPrefix("lnbc") && 
           !lowercased.hasPrefix("lntb") && 
           !lowercased.hasPrefix("lnbcrt") {
            errors.append("Invalid Lightning invoice prefix")
        }
        
        // Minimum length check
        if trimmed.count < 10 {
            errors.append("Invoice too short")
        }
        
        // Maximum length check (reasonable bound)
        if trimmed.count > 2000 {
            errors.append("Invoice too long")
        }
        
        // Basic character validation (should be Bech32)
        let validChars = CharacterSet(charactersIn: "qpzry9x8gf2tvdw0s3jn54khce6mua7l")
        let invoiceChars = CharacterSet(charactersIn: trimmed.lowercased())
        if !validChars.isSuperset(of: invoiceChars) {
            errors.append("Invoice contains invalid characters")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate quote ID format
    /// - Parameter quoteID: Quote identifier
    /// - Returns: Validation result
    public static func validateQuoteID(_ quoteID: String) -> ValidationResult {
        var errors: [String] = []
        
        let trimmed = quoteID.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            errors.append("Quote ID cannot be empty")
        }
        
        // Quote IDs should be reasonable length
        if trimmed.count < 8 {
            errors.append("Quote ID too short")
        }
        
        if trimmed.count > 128 {
            errors.append("Quote ID too long")
        }
        
        // Should not contain whitespace or control characters
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            errors.append("Quote ID cannot contain whitespace")
        }
        
        if trimmed.rangeOfCharacter(from: .controlCharacters) != nil {
            errors.append("Quote ID cannot contain control characters")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Keyset Validation
    
    /// Validate keyset ID format (stricter than existing)
    /// - Parameter keysetID: Keyset identifier
    /// - Returns: Validation result
    public static func validateKeysetID(_ keysetID: String) -> ValidationResult {
        var errors: [String] = []
        
        // Must be exactly 16 characters
        if keysetID.count != 16 {
            errors.append("Keyset ID must be exactly 16 characters")
        }
        
        // Must be valid hex
        let hexPattern = "^[0-9A-Fa-f]{16}$"
        do {
            let regex = try NSRegularExpression(pattern: hexPattern)
            let range = NSRange(location: 0, length: keysetID.count)
            
            if regex.firstMatch(in: keysetID, options: [], range: range) == nil {
                errors.append("Keyset ID must be valid hexadecimal")
            }
        } catch {
            errors.append("Failed to validate keyset ID format")
        }
        
        // Must start with version byte 00
        if !keysetID.hasPrefix("00") {
            errors.append("Keyset ID must start with version byte 00")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Array Validation
    
    /// Validate proof array
    /// - Parameter proofs: Array of proofs to validate
    /// - Returns: Validation result
    public static func validateProofs(_ proofs: [Proof]) -> ValidationResult {
        var errors: [String] = []
        
        if proofs.isEmpty {
            errors.append("Proof array cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Check for reasonable array size
        if proofs.count > 1000 {
            errors.append("Too many proofs in array (maximum 1000)")
        }
        
        // Validate each proof
        for (index, proof) in proofs.enumerated() {
            let proofValidation = ValidationUtils.validateProof(proof)
            if !proofValidation.isValid {
                errors.append("Invalid proof at index \(index): \(proofValidation.errors.joined(separator: ", "))")
            }
        }
        
        // Check for duplicate proofs
        let uniqueProofs = Set(proofs.map { "\($0.amount):\($0.secret):\($0.C)" })
        if uniqueProofs.count != proofs.count {
            errors.append("Duplicate proofs detected")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate blinded messages array
    /// - Parameter messages: Array of blinded messages
    /// - Returns: Validation result
    public static func validateBlindedMessages(_ messages: [BlindedMessage]) -> ValidationResult {
        var errors: [String] = []
        
        if messages.isEmpty {
            errors.append("Blinded messages array cannot be empty")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Check for reasonable array size
        if messages.count > 1000 {
            errors.append("Too many blinded messages (maximum 1000)")
        }
        
        // Validate each message
        for (index, message) in messages.enumerated() {
            let amountValidation = validateAmount(message.amount)
            if !amountValidation.isValid {
                errors.append("Invalid amount in message at index \(index): \(amountValidation.errors.joined(separator: ", "))")
            }
            
            // Validate B_ field
            if message.B_.isEmpty {
                errors.append("B_ cannot be empty at index \(index)")
            }
            
            let hexValidation = ValidationUtils.validateHexString(message.B_)
            if !hexValidation.isValid {
                errors.append("Invalid B_ format at index \(index): \(hexValidation.errors.joined(separator: ", "))")
            }
            
            // Validate keyset ID if present
            if let keysetId = message.id {
                let keysetValidation = validateKeysetID(keysetId)
                if !keysetValidation.isValid {
                    errors.append("Invalid keyset ID at index \(index): \(keysetValidation.errors.joined(separator: ", "))")
                }
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Transaction Validation
    
    /// Validate swap transaction balance
    /// - Parameters:
    ///   - inputs: Input proofs
    ///   - outputs: Output amounts
    ///   - fee: Transaction fee
    /// - Returns: Validation result
    public static func validateSwapBalance(inputs: [Proof], outputs: [Int], fee: Int = 0) -> ValidationResult {
        var errors: [String] = []
        
        let inputSum = inputs.reduce(0) { $0 + $1.amount }
        let outputSum = outputs.reduce(0, +)
        
        if inputSum != outputSum + fee {
            errors.append("Transaction balance mismatch: inputs=\(inputSum), outputs=\(outputSum), fee=\(fee)")
        }
        
        // Validate fee is reasonable
        if fee < 0 {
            errors.append("Fee cannot be negative")
        }
        
        if fee > inputSum {
            errors.append("Fee cannot exceed input amount")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Rate Limiting and Bounds
    
    /// Validate request rate limits
    /// - Parameters:
    ///   - requestCount: Number of requests
    ///   - timeWindow: Time window in seconds
    ///   - maxRequests: Maximum allowed requests
    /// - Returns: Validation result
    public static func validateRateLimit(requestCount: Int, timeWindow: TimeInterval, maxRequests: Int) -> ValidationResult {
        var errors: [String] = []
        
        if requestCount > maxRequests {
            errors.append("Rate limit exceeded: \(requestCount) requests in \(timeWindow)s (max: \(maxRequests))")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Specialized NUT Validations
    
    /// Validate NUT-03 swap request
    /// - Parameter request: Swap request to validate
    /// - Returns: Validation result
    public static func validateSwapRequest(_ request: PostSwapRequest) -> ValidationResult {
        var errors: [String] = []
        
        // Validate inputs
        let inputValidation = validateProofs(request.inputs)
        if !inputValidation.isValid {
            errors.append("Invalid inputs: \(inputValidation.errors.joined(separator: ", "))")
        }
        
        // Validate outputs
        let outputValidation = validateBlindedMessages(request.outputs)
        if !outputValidation.isValid {
            errors.append("Invalid outputs: \(outputValidation.errors.joined(separator: ", "))")
        }
        
        // Validate balance
        let balanceValidation = validateSwapBalance(
            inputs: request.inputs,
            outputs: request.outputs.map { $0.amount }
        )
        if !balanceValidation.isValid {
            errors.append("Balance validation failed: \(balanceValidation.errors.joined(separator: ", "))")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate NUT-04 mint quote request
    /// - Parameter request: Mint quote request
    /// - Returns: Validation result
    public static func validateMintQuoteRequest(_ request: MintQuoteRequest) -> ValidationResult {
        var errors: [String] = []
        
        // Validate amount (if provided)
        if let amount = request.amount {
            let amountValidation = validateAmount(amount)
            if !amountValidation.isValid {
                errors.append("Invalid amount: \(amountValidation.errors.joined(separator: ", "))")
            }
        }
        
        // Validate unit
        let unitValidation = ValidationUtils.validateUnit(request.unit)
        if !unitValidation.isValid {
            errors.append("Invalid unit: \(unitValidation.errors.joined(separator: ", "))")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validate NUT-05 melt quote request
    /// - Parameter request: Melt quote request
    /// - Returns: Validation result
    public static func validateMeltQuoteRequest(_ request: PostMeltQuoteRequest) -> ValidationResult {
        var errors: [String] = []
        
        // Validate Lightning invoice
        let invoiceValidation = validateLightningInvoice(request.request)
        if !invoiceValidation.isValid {
            errors.append("Invalid Lightning invoice: \(invoiceValidation.errors.joined(separator: ", "))")
        }
        
        // Validate unit
        let unitValidation = ValidationUtils.validateUnit(request.unit)
        if !unitValidation.isValid {
            errors.append("Invalid unit: \(unitValidation.errors.joined(separator: ", "))")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// MARK: - Input Sanitization

public extension NUTValidation {
    
    /// Sanitize string input by removing dangerous characters
    /// - Parameter input: Raw string input
    /// - Returns: Sanitized string
    static func sanitizeStringInput(_ input: String) -> String {
        return input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "") // Remove null bytes
            .filter { !$0.isNewline && !$0.isWhitespace || $0 == " " } // Keep only spaces
    }
    
    /// Validate and sanitize hex string
    /// - Parameter hex: Raw hex string
    /// - Returns: Sanitized hex string or nil if invalid
    static func sanitizeHexString(_ hex: String) -> String? {
        let sanitized = sanitizeStringInput(hex)
        let validation = ValidationUtils.validateHexString(sanitized)
        return validation.isValid ? sanitized : nil
    }
}
