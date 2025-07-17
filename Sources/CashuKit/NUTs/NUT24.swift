//
//  NUT24.swift
//  CashuKit
//
//  NUT-24: HTTP 402 Payment Required
//

import Foundation

// MARK: - HTTP 402 Payment Request

/// Payment request for HTTP 402 responses as defined in NUT-24
public struct HTTP402PaymentRequest: CashuCodabale, Sendable {
    /// The amount required in the specified unit
    public let a: Int
    
    /// The currency unit (e.g., "sat", "usd", "api")
    public let u: String
    
    /// Array of mint URLs that the server accepts tokens from
    public let m: [String]
    
    /// The required NUT-10 locking condition (optional)
    public let nut10: NUT10Option?
    
    public init(amount: Int, unit: String, mints: [String], nut10: NUT10Option? = nil) {
        self.a = amount
        self.u = unit
        self.m = mints
        self.nut10 = nut10
    }
    
    /// Convenience properties
    public var amount: Int { a }
    public var unit: String { u }
    public var mints: [String] { m }
}

// MARK: - HTTP Headers

public enum CashuHTTPHeader {
    /// The header name for Cashu payment requests and tokens
    public static let xCashu = "X-Cashu"
}

// MARK: - HTTP 402 Response

/// Represents an HTTP 402 Payment Required response with Cashu payment details
public struct HTTP402Response: Sendable {
    /// The HTTP status code (always 402)
    public let statusCode: Int = 402
    
    /// The encoded payment request from the X-Cashu header
    public let paymentRequest: String
    
    /// The decoded payment request
    public let decodedRequest: HTTP402PaymentRequest?
    
    public init(paymentRequest: String) {
        self.paymentRequest = paymentRequest
        self.decodedRequest = Self.decodePaymentRequest(paymentRequest)
    }
    
    /// Decode the payment request from the X-Cashu header
    private static func decodePaymentRequest(_ encoded: String) -> HTTP402PaymentRequest? {
        // The payment request should be encoded as per NUT-18
        guard let data = Data(base64Encoded: encoded),
              let decoded = try? JSONDecoder().decode(HTTP402PaymentRequest.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - HTTP Client Extensions

/// Extensions for handling HTTP 402 responses
public struct CashuHTTPClient {
    
    /// Parse an HTTP 402 response with X-Cashu header
    public static func parsePaymentRequired(headers: [String: String]) -> HTTP402Response? {
        guard let xCashuValue = headers[CashuHTTPHeader.xCashu] else {
            return nil
        }
        return HTTP402Response(paymentRequest: xCashuValue)
    }
    
    /// Create payment headers with a Cashu token
    public static func createPaymentHeaders(token: CashuToken) -> [String: String] {
        // Encode the token as cashuB format
        // First encode to JSON, then base64
        guard let tokenData = try? JSONEncoder().encode(token) else {
            return [:]
        }
        
        let encodedToken = "cashuB" + tokenData.base64EncodedString()
        return [CashuHTTPHeader.xCashu: encodedToken]
    }
    
    /// Validate if a token meets the payment requirements
    public static func validateTokenForPayment(
        token: CashuToken,
        paymentRequest: HTTP402PaymentRequest
    ) -> PaymentValidationResult {
        // Check if token is from an accepted mint
        let tokenMint = token.token.first?.mint ?? ""
        guard paymentRequest.mints.contains(tokenMint) else {
            return .failure(.mintNotAccepted)
        }
        
        // Check if token has the correct unit
        let tokenUnit = token.unit ?? "sat"
        guard tokenUnit == paymentRequest.unit else {
            return .failure(.incorrectUnit)
        }
        
        // Check if token amount is sufficient
        let tokenAmount = token.totalAmount
        guard tokenAmount >= paymentRequest.amount else {
            return .failure(.insufficientAmount)
        }
        
        // Check NUT-10 locking conditions if required
        if let requiredNut10 = paymentRequest.nut10 {
            // Validate that all proofs meet the locking condition
            for tokenEntry in token.token {
                for proof in tokenEntry.proofs {
                    if !validateProofMeetsCondition(proof: proof, condition: requiredNut10) {
                        return .failure(.insufficientLockingConditions)
                    }
                }
            }
        }
        
        return .success
    }
    
    /// Validate if a proof meets the required NUT-10 condition
    private static func validateProofMeetsCondition(proof: Proof, condition: NUT10Option) -> Bool {
        // Check if proof has a well-known secret that matches the condition
        guard let wellKnownSecret = proof.getWellKnownSecret() else {
            return false
        }
        
        // Validate based on the condition type
        let conditionType = LockingConditionType(rawValue: condition.kind) ?? .unknown
        
        switch conditionType {
        case .p2pk:
            // For P2PK, check if the well-known secret matches the condition
            return wellKnownSecret.kind == SpendingConditionKind.p2pk
            
        case .htlc:
            // For HTLC, check if the well-known secret matches the condition
            return wellKnownSecret.kind == SpendingConditionKind.htlc
            
        case .unknown:
            // Unknown condition type
            return false
        }
    }
}

// MARK: - Payment Validation

/// Result of payment validation
public enum PaymentValidationResult {
    case success
    case failure(PaymentValidationError)
}

/// Errors that can occur during payment validation
public enum PaymentValidationError: Error, LocalizedError {
    case mintNotAccepted
    case incorrectUnit
    case insufficientAmount
    case insufficientLockingConditions
    
    public var errorDescription: String? {
        switch self {
        case .mintNotAccepted:
            return "Token is from a mint that is not accepted by the server"
        case .incorrectUnit:
            return "Token has incorrect unit"
        case .insufficientAmount:
            return "Token amount is insufficient"
        case .insufficientLockingConditions:
            return "Token does not meet required locking conditions"
        }
    }
}

// MARK: - HTTP 402 Payment Flow

/// Helper for managing HTTP 402 payment flows
public actor HTTP402PaymentFlow {
    
    /// Handle a 402 response and prepare payment
    public func handlePaymentRequired(
        response: HTTP402Response,
        availableTokens: [CashuToken]
    ) async throws -> CashuToken? {
        guard let paymentRequest = response.decodedRequest else {
            throw PaymentValidationError.incorrectUnit
        }
        
        // Find a suitable token from available tokens
        for token in availableTokens {
            let validation = CashuHTTPClient.validateTokenForPayment(
                token: token,
                paymentRequest: paymentRequest
            )
            
            if case .success = validation {
                return token
            }
        }
        
        return nil
    }
    
    /// Create a payment token that meets the requirements
    public func createPaymentToken(
        for paymentRequest: HTTP402PaymentRequest,
        from wallet: CashuWallet
    ) async throws -> CashuToken {
        // Find a mint that is accepted
        guard let acceptedMint = paymentRequest.mints.first else {
            throw PaymentValidationError.mintNotAccepted
        }
        
        // Get proofs from wallet for the required amount
        let proofs = try await wallet.selectProofs(
            amount: paymentRequest.amount,
            unit: paymentRequest.unit,
            mint: acceptedMint
        )
        
        // Create token from proofs
        let tokenEntry = TokenEntry(
            mint: acceptedMint,
            proofs: proofs
        )
        
        return CashuToken(
            token: [tokenEntry],
            unit: paymentRequest.unit
        )
    }
}

// MARK: - Convenience Extensions

extension CashuToken {
    /// Calculate the total amount of all proofs in the token
    public var totalAmount: Int {
        token.reduce(0) { total, entry in
            total + entry.proofs.reduce(0) { $0 + $1.amount }
        }
    }
}

extension CashuWallet {
    /// Select proofs for a specific amount, unit, and mint
    /// This is a placeholder - actual implementation would depend on wallet structure
    public func selectProofs(amount: Int, unit: String, mint: String) async throws -> [Proof] {
        // This would need to be implemented based on the actual wallet structure
        // For now, return empty array
        return []
    }
}