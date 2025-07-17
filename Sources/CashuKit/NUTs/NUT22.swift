//
//  NUT22.swift
//  CashuKit
//
//  NUT-22: Token Metadata for Non-Custodial Wallet Authentication
//  https://github.com/cashubtc/nuts/blob/main/22.md
//

import Foundation
import CryptoKit

// MARK: - NUT-22: Token Metadata for Non-Custodial Wallet Authentication

/// NUT-22: Token Metadata for Non-Custodial Wallet Authentication
/// This NUT defines a non-custodial wallet authentication scheme that allows operators to limit
/// the use of their mint to holders of access tokens issued by the mint.

// MARK: - Access Token

/// Access token structure for NUT-22
public struct AccessToken: CashuCodabale, Sendable {
    /// The access token to be included in swap operations
    public let access: String
    
    public init(access: String) {
        self.access = access
    }
}

// MARK: - Request Models

/// Request to retrieve access tokens from the mint
public struct PostAccessTokenRequest: CashuCodabale, Sendable {
    /// Quote ID from NUT-04 mint operation
    public let quoteId: String
    
    /// Blinded messages for the access tokens
    public let blindedMessages: [BlindedMessage]
    
    private enum CodingKeys: String, CodingKey {
        case quoteId = "quote_id"
        case blindedMessages = "blinded_messages"
    }
    
    public init(quoteId: String, blindedMessages: [BlindedMessage]) {
        self.quoteId = quoteId
        self.blindedMessages = blindedMessages
    }
}

/// Response containing blind signatures for access tokens
public struct PostAccessTokenResponse: CashuCodabale, Sendable {
    /// Blind signatures from the mint
    public let signatures: [BlindSignature]
    
    public init(signatures: [BlindSignature]) {
        self.signatures = signatures
    }
}

// MARK: - Extended Swap Request

/// Extended swap request including access token
public struct NUT22SwapRequest: CashuCodabale, Sendable {
    /// Proofs to be spent
    public let inputs: [Proof]
    
    /// Blinded messages for new tokens
    public let outputs: [BlindedMessage]
    
    /// Access token for authentication
    public let accessToken: AccessToken?
    
    private enum CodingKeys: String, CodingKey {
        case inputs
        case outputs
        case accessToken = "access_token"
    }
    
    public init(inputs: [Proof], outputs: [BlindedMessage], accessToken: AccessToken? = nil) {
        self.inputs = inputs
        self.outputs = outputs
        self.accessToken = accessToken
    }
}

// MARK: - NUT-22 Settings

/// NUT-22 settings for non-custodial wallet authentication
public struct NUT22Settings: CashuCodabale, Sendable {
    /// Whether access tokens are required for all operations
    public let mandatory: Bool
    
    /// Endpoints that require access tokens (when not mandatory)
    public let endpoints: [String]?
    
    public init(mandatory: Bool, endpoints: [String]? = nil) {
        self.mandatory = mandatory
        self.endpoints = endpoints
    }
    
    /// Check if access token is required for a specific endpoint
    public func requiresAccessToken(for endpoint: String) -> Bool {
        if mandatory {
            return true
        }
        
        guard let endpoints = endpoints else {
            return false
        }
        
        return endpoints.contains(endpoint)
    }
}

// MARK: - Access Token Service

/// Service for managing NUT-22 access tokens
public actor AccessTokenService: Sendable {
    private let networkService: any NetworkService
    private var accessTokens: [String: [Proof]] = [:] // mintURL -> access tokens
    
    public init(networkService: any NetworkService) {
        self.networkService = networkService
    }
    
    /// Request access tokens from the mint
    public func requestAccessTokens(
        mintURL: String,
        quoteId: String,
        amount: Int,
        keysetId: String,
        blindingFactors: [Data]? = nil
    ) async throws -> [Proof] {
        // Generate secrets and blinding factors
        let secrets = try (0..<amount).map { _ in
            try generateRandomSecret()
        }
        
        let factors = try blindingFactors ?? (0..<amount).map { _ in
            try generateRandomBytes(count: 32)
        }
        
        // Create blinded messages
        let blindedMessages = try zip(secrets, factors).map { (secret, factor) in
            let B_ = try blindMessage(secret: secret, blindingFactor: factor)
            return BlindedMessage(amount: 1, id: keysetId, B_: B_.hexString)
        }
        
        // Request blind signatures
        let request = PostAccessTokenRequest(quoteId: quoteId, blindedMessages: blindedMessages)
        let response: PostAccessTokenResponse = try await networkService.execute(
            method: "POST",
            path: "/v1/access",
            payload: try request.toJSONData()
        )
        
        // Unblind signatures and create access token proofs
        let proofs = try zip(zip(response.signatures, secrets), factors).map { (sigSecret, factor) in
            let (signature, secret) = sigSecret
            let C = try unblindSignature(
                blindSignature: signature.C_,
                blindingFactor: factor,
                publicKey: nil // Would need actual public key from keyset
            )
            
            return Proof(
                amount: signature.amount,
                id: signature.id,
                secret: secret.hexString,
                C: C.hexString
            )
        }
        
        // Store access tokens
        accessTokens[mintURL] = proofs
        
        return proofs
    }
    
    /// Get a valid access token for a mint
    public func getAccessToken(for mintURL: String) -> Proof? {
        guard let tokens = accessTokens[mintURL], !tokens.isEmpty else {
            return nil
        }
        
        // Return the first available token
        // In a real implementation, you might want to track which tokens have been used
        return tokens.first
    }
    
    /// Remove a used access token
    public func consumeAccessToken(for mintURL: String, token: Proof) {
        guard var tokens = accessTokens[mintURL] else { return }
        tokens.removeAll { $0.C == token.C }
        accessTokens[mintURL] = tokens.isEmpty ? nil : tokens
    }
    
    /// Clear all access tokens for a mint
    public func clearAccessTokens(for mintURL: String) {
        accessTokens.removeValue(forKey: mintURL)
    }
    
    /// Check if we have access tokens for a mint
    public func hasAccessTokens(for mintURL: String) -> Bool {
        return !(accessTokens[mintURL]?.isEmpty ?? true)
    }
}


// MARK: - MintInfo Extensions

extension MintInfo {
    /// Check if the mint supports NUT-22 (Token Metadata)
    public var supportsNUT22: Bool {
        return supportsNUT("22")
    }
    
    /// Get NUT-22 settings if supported
    public func getNUT22Settings() -> NUT22Settings? {
        guard let nut22Data = nuts?["22"]?.dictionaryValue else { return nil }
        
        // Extract mandatory value from AnyCodable
        let mandatory: Bool
        if let mandatoryValue = nut22Data["mandatory"] as? AnyCodable {
            mandatory = mandatoryValue.boolValue ?? false
        } else if let mandatoryBool = nut22Data["mandatory"] as? Bool {
            mandatory = mandatoryBool
        } else {
            mandatory = false
        }
        
        // Extract endpoints array from AnyCodable
        let endpoints: [String]?
        if let endpointsValue = nut22Data["endpoints"] as? AnyCodable {
            switch endpointsValue {
            case .array(let arr):
                endpoints = arr.compactMap { $0.stringValue }
            default:
                endpoints = nil
            }
        } else if let endpointsArray = nut22Data["endpoints"] as? [String] {
            endpoints = endpointsArray
        } else {
            endpoints = nil
        }
        
        return NUT22Settings(mandatory: mandatory, endpoints: endpoints)
    }
}

// MARK: - Error Extensions

extension CashuError {
    /// Access token is required for this operation
    public static var accessTokenRequired: CashuError {
        return .networkError("Access token required for this operation")
    }
    
    /// Failed to obtain access token
    public static func accessTokenFailed(_ message: String) -> CashuError {
        return .networkError("Access token failed: \(message)")
    }
}

// MARK: - Helper Functions

/// Generate a random secret for access tokens
private func generateRandomSecret() throws -> Data {
    return try generateRandomBytes(count: 32)
}

/// Generate random bytes
private func generateRandomBytes(count: Int) throws -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    let result = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    guard result == errSecSuccess else {
        throw CashuError.keyGenerationFailed
    }
    return Data(bytes)
}

/// Blind a message (simplified - would need actual implementation)
private func blindMessage(secret: Data, blindingFactor: Data) throws -> Data {
    // This is a placeholder - actual implementation would use secp256k1 operations
    // to compute B_ = Y + rG where Y = hash_to_curve(secret)
    throw CashuError.nutNotImplemented("22 - blinding not fully implemented")
}

/// Unblind a signature (simplified - would need actual implementation)
private func unblindSignature(blindSignature: String, blindingFactor: Data, publicKey: Data?) throws -> Data {
    // This is a placeholder - actual implementation would use secp256k1 operations
    // to compute C = C_ - rK where K is the public key
    throw CashuError.nutNotImplemented("22 - unblinding not fully implemented")
}

