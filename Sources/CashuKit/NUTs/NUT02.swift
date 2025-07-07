//
//  NUT02.swift
//  CashuKit
//
//  NUT-02: Keysets and fees
//  https://github.com/cashubtc/nuts/blob/main/02.md
//

import Foundation
import P256K
import CryptoKit

// MARK: - NUT-02: Keysets and fees

/// NUT-02: Keysets and fees
/// This NUT defines the keyset and fee structure for Cashu mints

/// Keyset information structure
public struct KeysetInfo: Codable, Sendable {
    public let id: String
    public let unit: String
    public let active: Bool
    public let inputFeePpk: Int?
    
    public init(id: String, unit: String, active: Bool, inputFeePpk: Int? = nil) {
        self.id = id
        self.unit = unit
        self.active = active
        self.inputFeePpk = inputFeePpk
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case unit
        case active
        case inputFeePpk = "input_fee_ppk"
    }
}

/// Keyset with public keys
public struct Keyset: Codable, Sendable {
    public let id: String
    public let unit: String
    public let keys: [String: String] // amount -> public key
    
    public init(id: String, unit: String, keys: [String: String]) {
        self.id = id
        self.unit = unit
        self.keys = keys
    }
    
    /// Get the public key for a specific amount
    public func getPublicKey(for amount: Int) -> String? {
        return keys[String(amount)]
    }
    
    /// Get all amounts supported by this keyset
    public func getSupportedAmounts() -> [Int] {
        return keys.keys.compactMap { Int($0) }.sorted()
    }
    
    /// Validate that all keys are valid hex strings
    public func validateKeys() -> Bool {
        return keys.values.allSatisfy { key in
            key.isValidHex && key.count == 66 // 33 bytes compressed key = 66 hex chars
        }
    }
}

/// Response structure for GET /v1/keysets
public struct GetKeysetsResponse: Codable, Sendable {
    public let keysets: [KeysetInfo]
    
    public init(keysets: [KeysetInfo]) {
        self.keysets = keysets
    }
}

/// Response structure for GET /v1/keys and GET /v1/keys/{keyset_id}
public struct GetKeysResponse: Codable, Sendable {
    public let keysets: [Keyset]
    
    public init(keysets: [Keyset]) {
        self.keysets = keysets
    }
}

// MARK: - Keyset ID Derivation

/// Keyset ID utilities
public struct KeysetID {
    /// Current keyset ID version
    public static let currentVersion = "00"
    
    /// Derive keyset ID from public keys
    /// Following NUT-02 specification:
    /// 1. Sort public keys by their amount in ascending order
    /// 2. Concatenate all public keys to one byte array
    /// 3. HASH_SHA256 the concatenated public keys
    /// 4. Take the first 14 characters of the hex-encoded hash
    /// 5. Prefix it with a keyset ID version byte
    public static func deriveKeysetID(from keys: [String: String]) -> String {
        // Sort keys by amount (ascending order)
        let sortedKeys = keys.sorted { lhs, rhs in
            let lhsAmount = Int(lhs.key) ?? 0
            let rhsAmount = Int(rhs.key) ?? 0
            return lhsAmount < rhsAmount
        }
        
        // Concatenate all public keys
        var concatenatedKeys = Data()
        for (_, publicKeyHex) in sortedKeys {
            if let keyData = Data(hexString: publicKeyHex) {
                concatenatedKeys.append(keyData)
            }
        }
        
        // Hash the concatenated keys
        let hash = SHA256.hash(data: concatenatedKeys)
        let hashHex = Data(hash).hexString
        
        // Take first 14 characters and prefix with version
        let keysetID = currentVersion + String(hashHex.prefix(14))
        
        return keysetID
    }
    
    /// Validate keyset ID format
    public static func validateKeysetID(_ id: String) -> Bool {
        // Must be 16 characters (2 for version + 14 for hash)
        guard id.count == 16 else { return false }
        
        // Must be valid hex
        guard id.isValidHex else { return false }
        
        // Must start with current version
        guard id.hasPrefix(currentVersion) else { return false }
        
        return true
    }
}

// MARK: - Fee Calculation

/// Fee calculation utilities
public struct FeeCalculator {
    /// Calculate fees for a list of proofs
    /// Following NUT-02 specification:
    /// fees = ceil(sum(input_fee_ppk) / 1000)
    public static func calculateFees(for proofs: [String: Int]) -> Int {
        let sumFees = proofs.values.reduce(0, +)
        return (sumFees + 999) / 1000 // Integer division equivalent to ceil(sumFees / 1000)
    }
    
    /// Calculate total fee for inputs from different keysets
    public static func calculateTotalFee(inputs: [(keysetID: String, inputFeePpk: Int)]) -> Int {
        let totalFeePpk = inputs.reduce(0) { sum, input in
            sum + input.inputFeePpk
        }
        return (totalFeePpk + 999) / 1000
    }
}

// MARK: - Keyset Service

@CashuActor
public struct KeysetService: Sendable {
    private let router: NetworkRouter<KeysetAPI>
    
    public init() async {
        self.router = NetworkRouter<KeysetAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Get all keysets from a mint URL
    /// - parameter mintURL: The base URL of the mint
    /// - returns: GetKeysetsResponse with keyset information
    public func getKeysets(from mintURL: String) async throws -> GetKeysetsResponse {
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.getKeysets)
    }
    
    /// Get all keys from a mint URL
    /// - parameter mintURL: The base URL of the mint
    /// - returns: GetKeysResponse with all keysets and their keys
    public func getKeys(from mintURL: String) async throws -> GetKeysResponse {
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.getKeys)
    }
    
    /// Get keys for a specific keyset
    /// - parameters:
    ///   - mintURL: The base URL of the mint
    ///   - keysetID: The ID of the keyset to fetch
    /// - returns: GetKeysResponse with the requested keyset
    public func getKeys(from mintURL: String, keysetID: String) async throws -> GetKeysResponse {
        let normalizedURL = try normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        guard KeysetID.validateKeysetID(keysetID) else {
            throw CashuError.invalidKeysetID
        }
        
        return try await router.execute(.getKeysForKeyset(keysetID))
    }
    
    /// Get active keysets only
    /// - parameter mintURL: The base URL of the mint
    /// - returns: Array of active KeysetInfo
    public func getActiveKeysets(from mintURL: String) async throws -> [KeysetInfo] {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.filter { $0.active }
    }
    
    /// Check if a keyset is active
    /// - parameters:
    ///   - keysetID: The keyset ID to check
    ///   - mintURL: The base URL of the mint
    /// - returns: True if the keyset is active, false otherwise
    public func isKeysetActive(keysetID: String, at mintURL: String) async throws -> Bool {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.first { $0.id == keysetID }?.active ?? false
    }
    
    /// Get keyset information by ID
    /// - parameters:
    ///   - keysetID: The keyset ID to find
    ///   - mintURL: The base URL of the mint
    /// - returns: KeysetInfo if found, nil otherwise
    public func getKeysetInfo(keysetID: String, from mintURL: String) async throws -> KeysetInfo? {
        let response = try await getKeysets(from: mintURL)
        return response.keysets.first { $0.id == keysetID }
    }
    
    // MARK: - Validation Methods
    
    /// Validate keyset information
    public nonisolated func validateKeyset(_ keyset: Keyset) -> Bool {
        guard !keyset.id.isEmpty,
              !keyset.unit.isEmpty,
              !keyset.keys.isEmpty else {
            return false
        }
        
        guard KeysetID.validateKeysetID(keyset.id) else {
            return false
        }
        
        return keyset.validateKeys()
    }
    
    /// Validate keysets response
    public nonisolated func validateKeysetsResponse(_ response: GetKeysetsResponse) -> Bool {
        guard !response.keysets.isEmpty else { return false }
        
        for keysetInfo in response.keysets {
            guard !keysetInfo.id.isEmpty,
                  !keysetInfo.unit.isEmpty,
                  KeysetID.validateKeysetID(keysetInfo.id) else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Utility Methods
    
    /// Normalize mint URL
    private nonisolated func normalizeMintURL(_ mintURL: String) throws -> String {
        var normalizedURL = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !normalizedURL.contains("://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        
        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = url.host,
              !host.isEmpty else {
            throw CashuError.invalidMintURL
        }
        
        return normalizedURL
    }
}

// MARK: - API Endpoints

enum KeysetAPI {
    case getKeysets
    case getKeys
    case getKeysForKeyset(String)
}

extension KeysetAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL, 
              let url = URL(string: baseURL) else { 
            fatalError("The baseURL for the mint must be set") 
        }
        return url
    }
    
    var path: String {
        switch self {
        case .getKeysets:
            return "/v1/keysets"
        case .getKeys:
            return "/v1/keys"
        case .getKeysForKeyset(let keysetID):
            return "/v1/keys/\(keysetID)"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .getKeysets, .getKeys, .getKeysForKeyset:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .getKeysets, .getKeys, .getKeysForKeyset:
            return .request
        }
    }
    
    var headers: HTTPHeaders? {
        return ["Accept": "application/json"]
    }
}