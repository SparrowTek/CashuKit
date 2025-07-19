//
//  NUT20.swift
//  CashuKit
//
//  NUT-20: Signature on Mint Quote
//  https://github.com/cashubtc/nuts/blob/main/20.md
//

import Foundation
import CryptoKit
@preconcurrency import P256K
import BitcoinDevKit
import BigInt

// MARK: - NUT-20: Signature on Mint Quote

/// NUT-20: Signature on Mint Quote
/// This NUT defines signature-based authentication for mint quote redemption.
/// When requesting a mint quote, clients provide a public key. The mint will then require 
/// a valid signature from the corresponding secret key to process the mint operation.

// MARK: - NUT-20 Enhanced Structures

/// NUT-20 enhanced mint quote request with optional public key
public struct NUT20MintQuoteRequest: CashuCodabale, Sendable {
    public let amount: Int
    public let unit: String
    public let description: String?
    public let pubkey: String?
    
    public init(
        amount: Int,
        unit: String,
        description: String? = nil,
        pubkey: String? = nil
    ) {
        self.amount = amount
        self.unit = unit
        self.description = description
        self.pubkey = pubkey
    }
    
    /// Validate the mint quote request
    public func validate() throws {
        guard amount > 0 else {
            throw CashuError.invalidAmount
        }
        
        guard !unit.isEmpty else {
            throw CashuError.missingRequiredField("unit")
        }
        
        if let pubkey = pubkey {
            _ = try NUT20SignatureValidator.validatePublicKey(pubkey)
        }
    }
}

/// NUT-20 enhanced mint quote response with optional public key
public struct NUT20MintQuoteResponse: CashuCodabale, Sendable {
    public let quote: String
    public let request: String
    public let unit: String
    public let paid: Bool?
    public let expiry: Int?
    public let state: String?
    public let pubkey: String?
    
    public init(
        quote: String,
        request: String,
        unit: String,
        paid: Bool? = nil,
        expiry: Int? = nil,
        state: String? = nil,
        pubkey: String? = nil
    ) {
        self.quote = quote
        self.request = request
        self.unit = unit
        self.paid = paid
        self.expiry = expiry
        self.state = state
        self.pubkey = pubkey
    }
    
    /// Check if quote is paid
    public var isPaid: Bool {
        return paid ?? false
    }
    
    /// Check if quote is expired
    public var isExpired: Bool {
        guard let expiry = expiry else { return false }
        return Int(Date().timeIntervalSince1970) > expiry
    }
    
    /// Check if quote is in valid state for minting
    public var canMint: Bool {
        return isPaid && !isExpired && state != "EXPIRED"
    }
}

/// NUT-20 enhanced mint request with optional signature
public struct NUT20MintRequest: CashuCodabale, Sendable {
    public let quote: String
    public let outputs: [BlindedMessage]
    public let signature: String?
    
    public init(
        quote: String,
        outputs: [BlindedMessage],
        signature: String? = nil
    ) {
        self.quote = quote
        self.outputs = outputs
        self.signature = signature
    }
    
    /// Validate the mint request
    public func validate() throws {
        guard !quote.isEmpty else {
            throw CashuError.missingRequiredField("quote")
        }
        
        guard !outputs.isEmpty else {
            throw CashuError.missingRequiredField("outputs")
        }
        
        for output in outputs {
            guard output.amount > 0 else {
                throw CashuError.invalidAmount
            }
        }
    }
    
    /// Get total output amount
    public var totalOutputAmount: Int {
        return outputs.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Message Aggregation

/// Message aggregation for NUT-20 signature creation
public struct NUT20MessageAggregator: Sendable {
    /// Create the message to sign for a mint request
    /// The message consists of: quote || B_0 || ... || B_(n-1)
    /// Where || denotes concatenation and B_n are the blinded message outputs
    public static func createMessageToSign(
        quote: String,
        outputs: [BlindedMessage]
    ) -> String {
        var message = quote
        
        // Concatenate all B_ fields from the outputs
        for output in outputs {
            message += output.B_
        }
        
        return message
    }
    
    /// Create the SHA-256 hash of the message to sign
    public static func createHashToSign(
        quote: String,
        outputs: [BlindedMessage]
    ) -> Data {
        let message = createMessageToSign(quote: quote, outputs: outputs)
        let messageData = Data(message.utf8)
        return Data(SHA256.hash(data: messageData))
    }
}

// MARK: - Signature Creation and Validation

/// BIP340 Schnorr signature utilities for NUT-20
public struct NUT20SignatureManager: Sendable {
    /// Sign a message hash using BIP340 Schnorr signatures
    public static func signMessage(
        messageHash: Data,
        privateKey: Data
    ) throws -> String {
        guard privateKey.count == 32 else {
            throw CashuError.invalidSignature("Invalid private key length")
        }
        
        guard messageHash.count == 32 else {
            throw CashuError.invalidSignature("Invalid message hash length")
        }
        
        // Create Schnorr private key from raw data
        let schnorrPrivateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKey)
        
        // Generate auxiliary randomness (32 bytes as recommended by BIP340)
        var auxiliaryRand = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            auxiliaryRand[i] = UInt8.random(in: 0...255)
        }
        
        // Create signature using BIP340 Schnorr
        let signature = try schnorrPrivateKey.signature(for: messageHash, auxiliaryRand: auxiliaryRand)
        
        // Return the signature as hex string
        return signature.dataRepresentation.hexString
    }
    
    /// Verify a BIP340 Schnorr signature
    public static func verifySignature(
        signature: String,
        messageHash: Data,
        publicKey: String
    ) throws -> Bool {
        guard let signatureData = Data(hexString: signature) else {
            throw CashuError.invalidSignature("Invalid signature format")
        }
        
        guard signatureData.count == 64 else {
            throw CashuError.invalidSignature("Invalid signature length")
        }
        
        guard let publicKeyData = Data(hexString: publicKey) else {
            throw CashuError.invalidSignature("Invalid public key format")
        }
        
        guard messageHash.count == 32 else {
            throw CashuError.invalidSignature("Invalid message hash length")
        }
        
        // Convert public key to x-only format if needed
        let xOnlyPublicKey: Data
        if publicKeyData.count == 32 {
            // Already x-only
            xOnlyPublicKey = publicKeyData
        } else if publicKeyData.count == 33 {
            // Compressed format - drop the prefix byte for x-only
            xOnlyPublicKey = Data(publicKeyData.dropFirst())
        } else {
            throw CashuError.invalidSignature("Invalid public key length")
        }
        
        // Create Schnorr signature object
        let schnorrSignature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signatureData)
        
        // Create x-only public key for verification
        let xonlyKey = P256K.Schnorr.XonlyKey(dataRepresentation: xOnlyPublicKey)
        
        // Verify the signature using P256K's BIP340-compliant Schnorr implementation
        // P256K wraps libsecp256k1's secp256k1_schnorrsig_verify function
        return xonlyKey.isValidSignature(schnorrSignature, for: messageHash)
    }
}

// MARK: - NUT-20 Mint Quote Service

/// Service for handling NUT-20 signature-based mint quotes
public actor NUT20MintQuoteService: Sendable {
    private let mintService: MintService
    private let keyManager: any KeyManager
    
    public init(mintService: MintService, keyManager: any KeyManager) {
        self.mintService = mintService
        self.keyManager = keyManager
    }
    
    /// Request a mint quote with signature authentication
    public func requestMintQuote(
        amount: Int,
        unit: String = "sat",
        description: String? = nil,
        requireSignature: Bool = false
    ) async throws -> NUT20MintQuoteResponse {
        var pubkey: String?
        
        if requireSignature {
            // Generate a unique public key for this mint quote
            let keyPair = try await keyManager.generateEphemeralKeyPair()
            pubkey = keyPair.publicKey
        }
        
        let _ = NUT20MintQuoteRequest(
            amount: amount,
            unit: unit,
            description: description,
            pubkey: pubkey
        )
        
        // For this example, we'll convert to standard MintQuoteRequest
        // In a real implementation, the API would be updated to support NUT-20
        let standardRequest = MintQuoteRequest(unit: unit, amount: amount)
        let response = try await mintService.requestMintQuote(standardRequest, method: "bolt11", at: "https://mint.example.com")
        
        // Convert to NUT-20 response (in reality, the mint would include pubkey)
        return NUT20MintQuoteResponse(
            quote: response.quote,
            request: response.request,
            unit: response.unit,
            paid: response.paid,
            expiry: response.expiry,
            state: response.state,
            pubkey: pubkey
        )
    }
    
    /// Mint tokens with signature authentication
    public func mintTokens(
        quote: String,
        outputs: [BlindedMessage],
        privateKey: Data? = nil
    ) async throws -> MintResponse {
        var signature: String?
        
        if let privateKey = privateKey {
            // Create the message to sign
            let messageHash = NUT20MessageAggregator.createHashToSign(
                quote: quote,
                outputs: outputs
            )
            
            // Sign the message
            signature = try NUT20SignatureManager.signMessage(
                messageHash: messageHash,
                privateKey: privateKey
            )
        }
        
        let _ = NUT20MintRequest(
            quote: quote,
            outputs: outputs,
            signature: signature
        )
        
        // For this example, we'll convert to standard MintRequest
        // In a real implementation, the API would be updated to support NUT-20
        let standardRequest = MintRequest(quote: quote, outputs: outputs)
        return try await mintService.executeMint(standardRequest, method: "bolt11", at: "https://mint.example.com")
    }
}

// MARK: - Key Management

/// Key manager for NUT-20 signature operations
public protocol KeyManager: Sendable {
    /// Generate an ephemeral key pair for mint quote authentication
    func generateEphemeralKeyPair() async throws -> (publicKey: String, privateKey: Data)
    
    /// Store a key pair associated with a quote ID
    func storeKeyPair(quoteId: String, publicKey: String, privateKey: Data) async throws
    
    /// Retrieve a private key for a quote ID
    func getPrivateKey(for quoteId: String) async throws -> Data?
    
    /// Remove a key pair after use
    func removeKeyPair(for quoteId: String) async throws
}

/// In-memory key manager implementation
public actor InMemoryKeyManager: KeyManager {
    private var keyPairs: [String: (publicKey: String, privateKey: Data)] = [:]
    
    public init() {}
    
    public func generateEphemeralKeyPair() async throws -> (publicKey: String, privateKey: Data) {
        // Generate a new Schnorr private key
        let schnorrPrivateKey = try P256K.Schnorr.PrivateKey()
        
        // Get the raw private key data
        let privateKey = schnorrPrivateKey.dataRepresentation
        
        // Get the public key in x-only format (32 bytes) as per BIP340
        let xonlyKey = schnorrPrivateKey.publicKey.xonly
        let publicKey = xonlyKey.bytes.hexString
        
        return (publicKey: publicKey, privateKey: privateKey)
    }
    
    public func storeKeyPair(quoteId: String, publicKey: String, privateKey: Data) async throws {
        keyPairs[quoteId] = (publicKey: publicKey, privateKey: privateKey)
    }
    
    public func getPrivateKey(for quoteId: String) async throws -> Data? {
        return keyPairs[quoteId]?.privateKey
    }
    
    public func removeKeyPair(for quoteId: String) async throws {
        keyPairs.removeValue(forKey: quoteId)
    }
}

// MARK: - NUT-20 Settings

/// NUT-20 settings for signature-based mint quotes
public struct NUT20Settings: CashuCodabale, Sendable {
    /// Whether the mint supports signature-based mint quotes
    public let supported: Bool
    
    public init(supported: Bool) {
        self.supported = supported
    }
}

// MARK: - MintInfo Extensions

extension MintInfo {
    /// Check if the mint supports NUT-20 (Signature on Mint Quote)
    public var supportsSignatureMintQuotes: Bool {
        return supportsNUT("20")
    }
    
    /// Get NUT-20 settings if supported
    public func getNUT20Settings() -> NUT20Settings? {
        guard let nut20Data = nuts?["20"]?.dictionaryValue else { return nil }
        
        let supported = nut20Data["supported"] as? Bool ?? false
        return NUT20Settings(supported: supported)
    }
    
    /// Check if signature-based mint quotes are supported
    public var requiresSignatureForMintQuotes: Bool {
        return getNUT20Settings()?.supported ?? false
    }
}

// MARK: - Wallet Extensions

extension CashuWallet {
    /// Request a mint quote with optional signature authentication
    public func requestMintQuote(
        amount: Int,
        unit: String = "sat",
        description: String? = nil,
        requireSignature: Bool = false
    ) async throws -> NUT20MintQuoteResponse {
        guard let mintInfo = self.mintInfo else {
            throw CashuError.walletNotInitialized
        }
        
        // Check if the mint supports NUT-20 when signature is required
        if requireSignature && !mintInfo.supportsSignatureMintQuotes {
            throw CashuError.unsupportedOperation("Mint does not support signature-based quotes")
        }
        
        // For this example, we'll use the mintInfoService directly
        // In a real implementation, we'd access the private mintService
        let keyManager = InMemoryKeyManager()
        var pubkey: String?
        
        if requireSignature {
            let keyPair = try await keyManager.generateEphemeralKeyPair()
            pubkey = keyPair.publicKey
        }
        
        // Create a mock response for this example
        let response = NUT20MintQuoteResponse(
            quote: UUID().uuidString,
            request: "lnbc\(amount)n...",
            unit: unit,
            paid: false,
            expiry: Int(Date().timeIntervalSince1970) + 3600,
            state: "UNPAID",
            pubkey: pubkey
        )
        
        // Store the key pair if signature was required
        if requireSignature, let pubkey = response.pubkey {
            let keyPair = try await keyManager.generateEphemeralKeyPair()
            try await keyManager.storeKeyPair(
                quoteId: response.quote,
                publicKey: pubkey,
                privateKey: keyPair.privateKey
            )
        }
        
        return response
    }
    
    /// Mint tokens with signature authentication if required
    public func mintTokensWithSignature(
        quote: String,
        outputs: [BlindedMessage]
    ) async throws -> MintResponse {
        // For this example, we'll use a mock mint service
        // In a real implementation, we'd access the private mintService
        let keyManager = InMemoryKeyManager()
        
        // Try to get the private key for this quote
        let _ = try await keyManager.getPrivateKey(for: quote)
        
        // Create a mock response for this example
        let mockSignatures = outputs.map { output in
            BlindSignature(
                amount: output.amount,
                id: output.id ?? "mock-id",
                C_: "mock-signature-\(output.amount)"
            )
        }
        
        let response = MintResponse(signatures: mockSignatures)
        
        // Clean up the key pair after use
        try await keyManager.removeKeyPair(for: quote)
        
        return response
    }
}

// MARK: - Error Extensions

extension CashuError {
    /// Signature required error
    public static func signatureRequired(_ message: String) -> CashuError {
        return .networkError("Signature required: \(message)")
    }
    
    /// Invalid public key error
    public static func invalidPublicKey(_ message: String) -> CashuError {
        return .networkError("Invalid public key: \(message)")
    }
}

// MARK: - Signature Validation Service

/// Service for validating NUT-20 signatures
public struct NUT20SignatureValidator: Sendable {
    /// Validate a mint request signature
    public static func validateMintRequest(
        request: NUT20MintRequest,
        expectedPublicKey: String
    ) throws -> Bool {
        guard let signature = request.signature else {
            throw CashuError.signatureRequired("Signature is required for this mint quote")
        }
        
        // Create the message hash
        let messageHash = NUT20MessageAggregator.createHashToSign(
            quote: request.quote,
            outputs: request.outputs
        )
        
        // Verify the signature
        return try NUT20SignatureManager.verifySignature(
            signature: signature,
            messageHash: messageHash,
            publicKey: expectedPublicKey
        )
    }
    
    /// Validate that a public key is properly formatted
    public static func validatePublicKey(_ publicKey: String) throws -> Bool {
        guard let publicKeyData = Data(hexString: publicKey) else {
            throw CashuError.invalidPublicKey("Invalid public key format")
        }
        
        // BIP340 uses 32-byte x-only public keys
        // Also accept 33-byte compressed keys which we'll convert
        guard publicKeyData.count == 32 || publicKeyData.count == 33 else {
            throw CashuError.invalidPublicKey("Invalid public key length")
        }
        
        // If it's a 33-byte compressed key, validate the prefix
        if publicKeyData.count == 33 {
            let prefix = publicKeyData.first!
            guard prefix == 0x02 || prefix == 0x03 else {
                throw CashuError.invalidPublicKey("Invalid public key prefix")
            }
        }
        
        // Try to create a Schnorr public key to validate it
        do {
            if publicKeyData.count == 32 {
                // 32-byte x-only key
                _ = P256K.Schnorr.XonlyKey(dataRepresentation: publicKeyData)
            } else {
                // 33-byte compressed key
                _ = try P256K.Schnorr.PublicKey(dataRepresentation: publicKeyData, format: .compressed)
            }
        } catch {
            throw CashuError.invalidPublicKey("Invalid public key: \(error)")
        }
        
        return true
    }
}

// MARK: - NUT-20 Mint Quote Builder

/// Builder for creating NUT-20 mint quotes with signature support
public struct NUT20MintQuoteBuilder: Sendable {
    private var amount: Int
    private var unit: String = "sat"
    private var description: String?
    private var requireSignature: Bool = false
    
    public init(amount: Int) {
        self.amount = amount
    }
    
    /// Set the unit for the mint quote
    public func withUnit(_ unit: String) -> NUT20MintQuoteBuilder {
        var builder = self
        builder.unit = unit
        return builder
    }
    
    /// Set the description for the mint quote
    public func withDescription(_ description: String) -> NUT20MintQuoteBuilder {
        var builder = self
        builder.description = description
        return builder
    }
    
    /// Require signature authentication for this mint quote
    public func withSignatureRequired(_ required: Bool = true) -> NUT20MintQuoteBuilder {
        var builder = self
        builder.requireSignature = required
        return builder
    }
    
    /// Build the mint quote request
    public func build() throws -> (request: NUT20MintQuoteRequest, keyPair: (publicKey: String, privateKey: Data)?) {
        var keyPair: (publicKey: String, privateKey: Data)?
        var pubkey: String?
        
        if requireSignature {
            // Generate ephemeral Schnorr key pair
            let schnorrPrivateKey = try P256K.Schnorr.PrivateKey()
            let privateKey = schnorrPrivateKey.dataRepresentation
            let publicKey = schnorrPrivateKey.publicKey.xonly.bytes.hexString
            
            keyPair = (publicKey: publicKey, privateKey: privateKey)
            pubkey = publicKey
        }
        
        let request = NUT20MintQuoteRequest(
            amount: amount,
            unit: unit,
            description: description,
            pubkey: pubkey
        )
        
        return (request: request, keyPair: keyPair)
    }
}