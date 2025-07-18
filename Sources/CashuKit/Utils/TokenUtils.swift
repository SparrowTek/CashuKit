//
//  TokenUtils.swift
//  CashuKit
//
//  Token serialization and utility functions
//

import Foundation
import SwiftCBOR
@preconcurrency import P256K

// MARK: - Token Version Enum

/// Token serialization version
public enum TokenVersion: String, CaseIterable {
    case v3 = "A"
    case v4 = "B"
    
    public var description: String {
        switch self {
        case .v3: return "V3 (JSON base64)"
        case .v4: return "V4 (CBOR binary)"
        }
    }
}

// MARK: - Token Serialization Utilities

/// Utilities for token serialization and deserialization following NUT-00 specification
public struct CashuTokenUtils {
    
    // MARK: - Token Serialization Constants
    
    private static let tokenPrefix = "cashu"
    private static let versionV3: Character = "A"
    private static let versionV4: Character = "B"
    private static let uriScheme = "cashu:"
    
    // MARK: - V3 Token Serialization (Deprecated but supported)
    
    /// Serialize a CashuToken to V3 format (base64-encoded JSON)
    /// Format: cashuA[base64_token_json]
    public static func serializeTokenV3(_ token: CashuToken, includeURI: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(token)
        
        // Base64 URL-safe encoding
        let base64String = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
        let serializedToken = tokenPrefix + String(versionV3) + base64String
        
        return includeURI ? uriScheme + serializedToken : serializedToken
    }
    
    /// Deserialize a V3 token from serialized format
    public static func deserializeTokenV3(_ serializedToken: String) throws -> CashuToken {
        var token = serializedToken
        
        // Remove URI scheme if present
        if token.hasPrefix(uriScheme) {
            token = String(token.dropFirst(uriScheme.count))
        }
        
        // Validate prefix and version
        guard token.hasPrefix(tokenPrefix + String(versionV3)) else {
            throw CashuError.invalidTokenFormat
        }
        
        // Extract base64 part
        let base64Part = String(token.dropFirst(tokenPrefix.count + 1))
        
        // Convert back from URL-safe base64
        var base64String = base64Part
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        // Add padding if needed
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64String) else {
            throw CashuError.deserializationFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CashuToken.self, from: data)
    }
    
    // MARK: - V4 Token Serialization (Space-efficient CBOR format)
    
    /// V4 Token structure with shortened keys
    private struct TokenV4: CashuCodabale {
        let m: String // mint URL
        let u: String // unit
        let d: String? // memo (optional)
        let t: [KeysetGroup] // token groups by keyset
        
        struct KeysetGroup: CashuCodabale {
            let i: Data // keyset ID (as bytes)
            let p: [ProofV4] // proofs for this keyset
        }
        
        struct ProofV4: CashuCodabale {
            let a: Int // amount
            let s: String // secret
            let c: Data // signature (as bytes)
        }
    }
    
    /// Serialize a CashuToken to V4 format (CBOR-encoded)
    /// Format: cashuB[base64_token_cbor]
    public static func serializeTokenV4(_ token: CashuToken, includeURI: Bool = false) throws -> String {
        // Convert token to V4 structure
        var keysetGroups: [TokenV4.KeysetGroup] = []
        
        // Group proofs by keyset ID
        var proofsByKeyset: [String: [Proof]] = [:]
        for entry in token.token {
            for proof in entry.proofs {
                proofsByKeyset[proof.id, default: []].append(proof)
            }
        }
        
        // Create keyset groups
        for (keysetID, proofs) in proofsByKeyset {
            guard let keysetData = Data(hexString: keysetID) else {
                throw CashuError.invalidKeysetID
            }
            
            let proofsV4 = proofs.map { proof in
                TokenV4.ProofV4(
                    a: proof.amount,
                    s: proof.secret,
                    c: Data(hexString: proof.C) ?? Data()
                )
            }
            
            keysetGroups.append(TokenV4.KeysetGroup(i: keysetData, p: proofsV4))
        }
        
        // Create V4 token structure
        let tokenV4 = TokenV4(
            m: token.token.first?.mint ?? "",
            u: token.unit ?? "sat",
            d: token.memo,
            t: keysetGroups
        )
        
        // Convert to CBOR
        let cborData = try encodeToCBOR(tokenV4)
        
        // Base64 URL-safe encode
        let base64Token = cborData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let serialized = "cashuB\(base64Token)"
        return includeURI ? "\(uriScheme)\(serialized)" : serialized
    }
    
    /// Deserialize a V4 token from serialized format
    public static func deserializeTokenV4(_ serializedToken: String) throws -> CashuToken {
        var token = serializedToken
        
        // Remove URI scheme if present
        if token.hasPrefix(uriScheme) {
            token = String(token.dropFirst(uriScheme.count))
        }
        
        // Check and remove V4 prefix
        guard token.hasPrefix("cashuB") else {
            throw CashuError.invalidTokenFormat
        }
        token = String(token.dropFirst(6))
        
        // Base64 URL-safe decode
        var base64 = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let cborData = Data(base64Encoded: base64) else {
            throw CashuError.invalidTokenFormat
        }
        
        // Decode CBOR
        let tokenV4: TokenV4 = try decodeFromCBOR(cborData)
        
        // Convert to CashuToken
        var proofs: [Proof] = []
        for keysetGroup in tokenV4.t {
            let keysetID = keysetGroup.i.hexString
            for proofV4 in keysetGroup.p {
                let proof = Proof(
                    amount: proofV4.a,
                    id: keysetID,
                    secret: proofV4.s,
                    C: proofV4.c.hexString
                )
                proofs.append(proof)
            }
        }
        
        let tokenEntry = TokenEntry(
            mint: tokenV4.m,
            proofs: proofs
        )
        
        return CashuToken(
            token: [tokenEntry],
            unit: tokenV4.u,
            memo: tokenV4.d
        )
    }
    
    // MARK: - Generic Token Serialization
    
    /// Serialize a CashuToken (defaults to V3 format)
    public static func serializeToken(_ token: CashuToken, version: TokenVersion = .v3, includeURI: Bool = false) throws -> String {
        switch version {
        case .v3:
            return try serializeTokenV3(token, includeURI: includeURI)
        case .v4:
            return try serializeTokenV4(token, includeURI: includeURI)
        }
    }
    
    /// Deserialize a token from serialized format (auto-detects version)
    public static func deserializeToken(_ serializedToken: String) throws -> CashuToken {
        var token = serializedToken
        
        // Remove URI scheme if present
        if token.hasPrefix(uriScheme) {
            token = String(token.dropFirst(uriScheme.count))
        }
        
        // Detect version
        guard token.hasPrefix(tokenPrefix) && token.count >= tokenPrefix.count + 1 else {
            throw CashuError.invalidTokenFormat
        }
        
        let versionChar = token[token.index(token.startIndex, offsetBy: tokenPrefix.count)]
        
        switch versionChar {
        case versionV3:
            return try deserializeTokenV3(serializedToken)
        case versionV4:
            return try deserializeTokenV4(serializedToken)
        default:
            throw CashuError.invalidTokenFormat
        }
    }
    
    // MARK: - Legacy JSON Serialization
    
    /// Serialize a CashuToken to JSON string (for debugging/logging)
    public static func serializeTokenJSON(_ token: CashuToken) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(token)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CashuError.serializationFailed
        }
        return jsonString
    }
    
    /// Deserialize a CashuToken from JSON string (for debugging/testing)
    public static func deserializeTokenJSON(_ jsonString: String) throws -> CashuToken {
        guard let data = jsonString.data(using: .utf8) else {
            throw CashuError.deserializationFailed
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CashuToken.self, from: data)
        } catch {
            throw CashuError.deserializationFailed
        }
    }
    
    /// Create a CashuToken from UnblindedToken and mint information
    public static func createToken(
        from unblindedToken: UnblindedToken,
        mintURL: String,
        amount: Int,
        unit: String? = nil,
        memo: String? = nil
    ) -> CashuToken {
        let proof = Proof(
            amount: amount,
            id: UUID().uuidString,
            secret: unblindedToken.secret,
            C: unblindedToken.signature.hexString
        )
        
        let tokenEntry = TokenEntry(
            mint: mintURL,
            proofs: [proof]
        )
        
        return CashuToken(
            token: [tokenEntry],
            unit: unit,
            memo: memo
        )
    }
    
    /// Extract all proofs from a CashuToken
    public static func extractProofs(from token: CashuToken) -> [Proof] {
        return token.token.flatMap { $0.proofs }
    }
    
    /// Validate token structure
    public static func validateToken(_ token: CashuToken) -> Bool {
        // Check that token has at least one entry
        guard !token.token.isEmpty else { return false }
        
        // Check that each token entry has at least one proof
        for entry in token.token {
            guard !entry.proofs.isEmpty else { return false }
            
            // Validate each proof
            for proof in entry.proofs {
                guard proof.amount > 0,
                      !proof.id.isEmpty,
                      !proof.secret.isEmpty,
                      !proof.C.isEmpty else {
                    return false
                }
                
                // Validate hex string format
                if Data(hexString: proof.C) == nil {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Verify token cryptographically (requires mint private keys for verification)
    /// - Parameters:
    ///   - token: Token to verify
    ///   - mintPrivateKeys: Dictionary of mint private keys by keyset ID and amount
    /// - Returns: True if all proofs are valid, false otherwise
    /// - Note: This is a simplified verification that requires access to mint private keys
    public static func verifyToken(_ token: CashuToken, mintPrivateKeys: [String: [Int: Data]]) async throws -> Bool {
        for entry in token.token {
            for proof in entry.proofs {
                // Get the appropriate private key for this proof amount
                guard let keysetKeys = mintPrivateKeys[proof.id],
                      let privateKeyData = keysetKeys[proof.amount],
                      let signatureData = Data(hexString: proof.C) else {
                    return false
                }
                
                // Create a mint instance with the private key
                let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateKeyData)
                let mint = try Mint(privateKey: privateKey)
                
                // Verify the proof using the mint's verification method
                let isValid = try mint.verifyToken(secret: proof.secret, signature: signatureData)
                
                if !isValid {
                    return false
                }
            }
        }
        return true
    }
    
    /// Calculate total value of a token
    /// - Parameter token: Token to calculate value for
    /// - Returns: Total value in base unit
    public static func calculateTokenValue(_ token: CashuToken) -> Int {
        return token.token.reduce(0) { total, entry in
            total + entry.proofs.reduce(0) { entryTotal, proof in
                entryTotal + proof.amount
            }
        }
    }
    
    /// Group proofs by mint URL
    /// - Parameter token: Token to group proofs from
    /// - Returns: Dictionary mapping mint URLs to arrays of proofs
    public static func groupProofsByMint(_ token: CashuToken) -> [String: [Proof]] {
        var groupedProofs: [String: [Proof]] = [:]
        
        for entry in token.token {
            if groupedProofs[entry.mint] == nil {
                groupedProofs[entry.mint] = []
            }
            groupedProofs[entry.mint]?.append(contentsOf: entry.proofs)
        }
        
        return groupedProofs
    }
    
    /// Create a token with multiple mint entries
    /// - Parameters:
    ///   - proofsByMint: Dictionary mapping mint URLs to proof arrays
    ///   - unit: Token unit (optional)
    ///   - memo: Token memo (optional)
    /// - Returns: CashuToken with multiple mint entries
    public static func createTokenFromMultipleMints(
        proofsByMint: [String: [Proof]],
        unit: String? = nil,
        memo: String? = nil
    ) -> CashuToken {
        let tokenEntries = proofsByMint.map { mintURL, proofs in
            TokenEntry(mint: mintURL, proofs: proofs)
        }
        
        return CashuToken(token: tokenEntries, unit: unit, memo: memo)
    }
    
    /// Split token into smaller amounts
    /// - Parameters:
    ///   - token: Token to split
    ///   - amounts: Array of amounts to split into
    /// - Returns: Array of tokens with the specified amounts
    /// - Note: This is a utility function for preparing tokens for splitting operations
    public static func prepareTokenForSplit(_ token: CashuToken, amounts: [Int]) -> [CashuToken] {
        let allProofs = extractProofs(from: token)
        let totalAmount = allProofs.reduce(0) { $0 + $1.amount }
        let requestedAmount = amounts.reduce(0, +)
        
        guard requestedAmount <= totalAmount else {
            return [] // Cannot split if requested amount exceeds available
        }
        
        // This is a simplified approach - in practice, you'd need to use the swap operation
        // to actually split proofs into the desired denominations
        var result: [CashuToken] = []
        var remainingProofs = allProofs
        
        for amount in amounts {
            var currentAmount = 0
            var selectedProofs: [Proof] = []
            
            for (index, proof) in remainingProofs.enumerated() {
                if currentAmount + proof.amount <= amount {
                    selectedProofs.append(proof)
                    currentAmount += proof.amount
                    remainingProofs.remove(at: index)
                    
                    if currentAmount == amount {
                        break
                    }
                }
            }
            
            if currentAmount == amount {
                // Create token entry using the first mint URL from the original token
                let mintURL = token.token.first?.mint ?? ""
                let tokenEntry = TokenEntry(mint: mintURL, proofs: selectedProofs)
                result.append(CashuToken(token: [tokenEntry], unit: token.unit, memo: token.memo))
            }
        }
        
        return result
    }
    
    // MARK: - Import/Export Functionality
    
    /// Export token to various formats
    /// - Parameters:
    ///   - token: Token to export
    ///   - format: Export format
    ///   - includeURI: Whether to include cashu: URI scheme
    /// - Returns: Exported token string
    public static func exportToken(_ token: CashuToken, format: ExportFormat, includeURI: Bool = false) throws -> String {
        switch format {
        case .serialized:
            return try serializeToken(token, includeURI: includeURI)
        case .json:
            return try serializeTokenJSON(token)
        case .qrCode:
            return try serializeToken(token, includeURI: true) // Always include URI for QR codes
        }
    }
    
    /// Import token from various formats
    /// - Parameters:
    ///   - tokenString: Token string to import
    ///   - format: Import format (auto-detected if nil)
    /// - Returns: Imported CashuToken
    public static func importToken(_ tokenString: String, format: ImportFormat? = nil) throws -> CashuToken {
        let detectedFormat = format ?? detectImportFormat(tokenString)
        
        switch detectedFormat {
        case .serialized:
            return try deserializeToken(tokenString)
        case .json:
            return try deserializeTokenJSON(tokenString)
        case .qrCode:
            // QR codes should contain serialized tokens
            return try deserializeToken(tokenString)
        }
    }
    
    /// Detect import format from token string
    /// - Parameter tokenString: Token string to analyze
    /// - Returns: Detected import format
    private static func detectImportFormat(_ tokenString: String) -> ImportFormat {
        let trimmed = tokenString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for cashu: URI scheme or cashu prefix
        if trimmed.hasPrefix("cashu:") || trimmed.hasPrefix("cashu") {
            return .serialized
        }
        
        // Check for JSON format
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return .json
        }
        
        // Default to serialized format
        return .serialized
    }
    
    /// Validate imported token
    /// - Parameters:
    ///   - token: Token to validate
    ///   - strictValidation: Whether to perform strict validation
    /// - Returns: Validation result
    public static func validateImportedToken(_ token: CashuToken, strictValidation: Bool = false) -> TokenValidationResult {
        var warnings: [String] = []
        var errors: [String] = []
        
        // Basic structure validation
        if !validateToken(token) {
            errors.append("Invalid token structure")
        }
        
        // Check for empty proofs
        for (index, entry) in token.token.enumerated() {
            if entry.proofs.isEmpty {
                errors.append("Token entry at index \(index) has no proofs")
            }
            
            // Validate mint URL format
            let mintValidation = ValidationUtils.validateMintURL(entry.mint)
            if !mintValidation.isValid {
                errors.append("Invalid mint URL at index \(index): \(mintValidation.allErrors)")
            }
        }
        
        // Check for duplicate proofs (potential security issue)
        let allProofs = extractProofs(from: token)
        let uniqueSecrets = Set(allProofs.map { $0.secret })
        if uniqueSecrets.count != allProofs.count {
            errors.append("Duplicate proofs detected - potential security issue")
        }
        
        // Check for very large amounts (potential overflow)
        let totalValue = calculateTokenValue(token)
        if totalValue > 21_000_000 * 100_000_000 { // 21M BTC in sats
            warnings.append("Token value exceeds maximum Bitcoin supply")
        }
        
        // Strict validation checks
        if strictValidation {
            // Check for reasonable proof amounts
            for proof in allProofs {
                if proof.amount > 1_000_000 { // 1M sats
                    warnings.append("Proof with unusually large amount: \(proof.amount)")
                }
            }
            
            // Check for valid secret formats
            for proof in allProofs {
                if proof.secret.count < 10 {
                    warnings.append("Proof with short secret (potential security issue)")
                }
            }
        }
        
        return TokenValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            totalValue: totalValue
        )
    }
    
    /// Create token backup data
    /// - Parameters:
    ///   - tokens: Array of tokens to backup
    ///   - metadata: Additional metadata
    /// - Returns: JSON string containing backup data
    public static func createTokenBackup(_ tokens: [CashuToken], metadata: TokenBackupMetadata? = nil) throws -> String {
        let backup = TokenBackup(
            version: "1.0",
            timestamp: Date(),
            tokens: tokens,
            metadata: metadata ?? TokenBackupMetadata()
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(backup)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CashuError.serializationFailed
        }
        
        return jsonString
    }
    
    /// Restore tokens from backup data
    /// - Parameter backupData: JSON string containing backup data
    /// - Returns: Array of restored tokens and metadata
    public static func restoreTokenBackup(_ backupData: String) throws -> (tokens: [CashuToken], metadata: TokenBackupMetadata?) {
        guard let data = backupData.data(using: .utf8) else {
            throw CashuError.deserializationFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup: TokenBackup
        do {
            backup = try decoder.decode(TokenBackup.self, from: data)
        } catch {
            throw CashuError.deserializationFailed
        }
        
        // Validate backup version
        if backup.version != "1.0" {
            throw CashuError.unsupportedVersion
        }
        
        return (tokens: backup.tokens, metadata: backup.metadata)
    }
}

// MARK: - Amount-Specific Key Management

/// Represents a mint's keys organized by amount
public struct MintKeys {
    /// Dictionary mapping amount to keypair
    private var keypairs: [Int: MintKeypair] = [:]
    
    public init() {}
    
    /// Get or create a keypair for a specific amount
    public mutating func getKeypair(for amount: Int) throws -> MintKeypair {
        if let existing = keypairs[amount] {
            return existing
        }
        
        let newKeypair = try MintKeypair()
        keypairs[amount] = newKeypair
        return newKeypair
    }
    
    /// Get all amounts that have keys
    public var amounts: [Int] {
        return Array(keypairs.keys).sorted()
    }
    
    /// Get public keys for all amounts
    public func getPublicKeys() -> [Int: String] {
        var publicKeys: [Int: String] = [:]
        for (amount, keypair) in keypairs {
            publicKeys[amount] = keypair.publicKey.dataRepresentation.hexString
        }
        return publicKeys
    }
    
    /// Verify a proof for a specific amount
    public func verifyProof(_ proof: Proof, for amount: Int) throws -> Bool {
        guard let keypair = keypairs[amount] else {
            throw CashuError.invalidSignature("No keypair found for amount \(amount)")
        }
        
        guard let signatureData = Data(hexString: proof.C) else {
            throw CashuError.invalidHexString
        }
        
        let mint = try Mint(privateKey: keypair.privateKey)
        return try mint.verifyToken(secret: proof.secret, signature: signatureData)
    }
}

// MARK: - Supporting Types for Import/Export

/// Token export formats
public enum ExportFormat: String, CaseIterable {
    case serialized = "serialized"
    case json = "json"
    case qrCode = "qr_code"
    
    public var displayName: String {
        switch self {
        case .serialized: return "Serialized Token"
        case .json: return "JSON Format"
        case .qrCode: return "QR Code"
        }
    }
}

/// Token import formats
public enum ImportFormat: String, CaseIterable {
    case serialized = "serialized"
    case json = "json"
    case qrCode = "qr_code"
    
    public var displayName: String {
        switch self {
        case .serialized: return "Serialized Token"
        case .json: return "JSON Format"
        case .qrCode: return "QR Code"
        }
    }
}

/// Token validation result for imports
public struct TokenValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let totalValue: Int
    
    public init(isValid: Bool, errors: [String], warnings: [String], totalValue: Int) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.totalValue = totalValue
    }
    
    public var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    public var allErrors: String {
        return errors.joined(separator: "; ")
    }
    
    public var allWarnings: String {
        return warnings.joined(separator: "; ")
    }
}

/// Token backup structure
public struct TokenBackup: CashuCodabale {
    public let version: String
    public let timestamp: Date
    public let tokens: [CashuToken]
    public let metadata: TokenBackupMetadata?
    
    public init(version: String, timestamp: Date, tokens: [CashuToken], metadata: TokenBackupMetadata?) {
        self.version = version
        self.timestamp = timestamp
        self.tokens = tokens
        self.metadata = metadata
    }
}

/// Token backup metadata
public struct TokenBackupMetadata: CashuCodabale {
    public let deviceName: String?
    public let appVersion: String?
    public let totalValue: Int?
    public let tokenCount: Int?
    public let mintUrls: [String]?
    public let notes: String?
    
    public init(
        deviceName: String? = nil,
        appVersion: String? = nil,
        totalValue: Int? = nil,
        tokenCount: Int? = nil,
        mintUrls: [String]? = nil,
        notes: String? = nil
    ) {
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.totalValue = totalValue
        self.tokenCount = tokenCount
        self.mintUrls = mintUrls
        self.notes = notes
    }
} 
