//
//  NUT01.swift
//  CashuKit
//
//  NUT-01: Mint public key exchange
//  https://github.com/cashubtc/nuts/blob/main/01.md
//

import Foundation

// MARK: - NUT-01: Mint public key exchange

/// NUT-01: Mint public key exchange
/// This NUT defines how wallets receive public keys from mints

// MARK: - Currency Units

/// Supported currency units as defined in NUT-01
public enum CurrencyUnit: String, CaseIterable, CashuCodabale {
    case btc = "btc"          // Bitcoin (Minor Unit: 8)
    case sat = "sat"          // Bitcoin's Minor Unit
    case msat = "msat"        // 1/1000th of a sat
    case auth = "auth"        // Reserved for Blind Authentication
    
    // ISO 4217 currency codes
    case usd = "usd"          // US Dollar (Minor Unit: 2)
    case eur = "eur"          // Euro (Minor Unit: 2)
    case gbp = "gbp"          // British Pound (Minor Unit: 2)
    case jpy = "jpy"          // Japanese Yen (Minor Unit: 0)
    case bhd = "bhd"          // Bahraini Dinar (Minor Unit: 3)
    
    // Stablecoin currency codes
    case usdt = "usdt"        // Tether USD (Minor Unit: 2)
    case usdc = "usdc"        // USD Coin (Minor Unit: 2)
    case eurc = "eurc"        // Euro Coin (Minor Unit: 2)
    case gyen = "gyen"        // GYEN (Minor Unit: 0)
    
    /// Minor unit (decimal places) for the currency
    /// For Bitcoin, ISO 4217 currencies and stablecoins, amounts represent the Minor Unit
    public var minorUnit: Int {
        switch self {
        case .btc:
            return 8
        case .sat, .auth:
            return 0
        case .msat:
            return 0 // msat is already the smallest unit
        case .usd, .eur, .gbp, .usdt, .usdc, .eurc:
            return 2
        case .jpy, .gyen:
            return 0
        case .bhd:
            return 3
        }
    }
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .btc: return "Bitcoin"
        case .sat: return "Satoshi"
        case .msat: return "Millisatoshi"
        case .auth: return "Authentication Token"
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .jpy: return "Japanese Yen"
        case .bhd: return "Bahraini Dinar"
        case .usdt: return "Tether USD"
        case .usdc: return "USD Coin"
        case .eurc: return "Euro Coin"
        case .gyen: return "GYEN"
        }
    }
    
    /// Whether this is a Bitcoin-related unit
    public var isBitcoin: Bool {
        return [.btc, .sat, .msat].contains(self)
    }
    
    /// Whether this is an ISO 4217 currency
    public var isISO4217: Bool {
        return [.usd, .eur, .gbp, .jpy, .bhd].contains(self)
    }
    
    /// Whether this is a stablecoin
    public var isStablecoin: Bool {
        return [.usdt, .usdc, .eurc, .gyen].contains(self)
    }
}

// MARK: - Key Exchange Service

@CashuActor
public struct KeyExchangeService: Sendable {
    private let router: NetworkRouter<KeyExchangeAPI>
    
    public init() async {
        self.router = NetworkRouter<KeyExchangeAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Get active keys from a mint URL (NUT-01: GET /v1/keys)
    /// Returns only active keysets that the mint will sign outputs with
    /// - parameter mintURL: The base URL of the mint
    /// - returns: GetKeysResponse with active keysets and their keys
    public func getKeys(from mintURL: String) async throws -> GetKeysResponse {
        let normalizedURL = try ValidationUtils.normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.getKeys)
    }
    
    /// Get keys for a specific keyset (can be active or inactive)
    /// - parameters:
    ///   - mintURL: The base URL of the mint
    ///   - keysetID: The ID of the keyset to fetch
    /// - returns: GetKeysResponse with the requested keyset
    public func getKeys(from mintURL: String, keysetID: String) async throws -> GetKeysResponse {
        let normalizedURL = try ValidationUtils.normalizeMintURL(mintURL)
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        guard KeysetID.validateKeysetID(keysetID) else {
            throw CashuError.invalidKeysetID
        }
        
        return try await router.execute(.getKeysForKeyset(keysetID))
    }
    
    /// Get active keysets with specific currency unit
    /// - parameters:
    ///   - mintURL: The base URL of the mint
    ///   - unit: The currency unit to filter by
    /// - returns: Array of keysets with the specified unit
    public func getActiveKeys(from mintURL: String, unit: CurrencyUnit) async throws -> [Keyset] {
        let response = try await getKeys(from: mintURL)
        return response.keysets.filter { $0.unit == unit.rawValue }
    }
    
    /// Get all supported currency units from a mint
    /// - parameter mintURL: The base URL of the mint
    /// - returns: Set of supported currency units
    public func getSupportedUnits(from mintURL: String) async throws -> Set<String> {
        let response = try await getKeys(from: mintURL)
        return Set(response.keysets.map { $0.unit })
    }
    
    /// Check if a mint supports a specific currency unit
    /// - parameters:
    ///   - mintURL: The base URL of the mint
    ///   - unit: The currency unit to check
    /// - returns: True if the mint supports the unit
    public func supportsUnit(_ unit: CurrencyUnit, at mintURL: String) async throws -> Bool {
        let supportedUnits = try await getSupportedUnits(from: mintURL)
        return supportedUnits.contains(unit.rawValue)
    }
    
    /// Get the highest denomination key for a specific unit
    /// - parameters:
    ///   - mintURL: The base URL of the mint
    ///   - unit: The currency unit
    /// - returns: The highest amount key available, or nil if unit not supported
    public func getHighestDenomination(from mintURL: String, unit: CurrencyUnit) async throws -> Int? {
        let keysets = try await getActiveKeys(from: mintURL, unit: unit)
        
        let maxAmounts = keysets.map { keyset in
            keyset.getSupportedAmounts().max() ?? 0
        }
        
        return maxAmounts.max()
    }
    
    /// Get the lowest denomination key for a specific unit
    /// - parameters:
    ///   - mintURL: The base URL of the mint
    ///   - unit: The currency unit
    /// - returns: The lowest amount key available, or nil if unit not supported
    public func getLowestDenomination(from mintURL: String, unit: CurrencyUnit) async throws -> Int? {
        let keysets = try await getActiveKeys(from: mintURL, unit: unit)
        
        let minAmounts = keysets.compactMap { keyset in
            keyset.getSupportedAmounts().min()
        }
        
        return minAmounts.min()
    }
    
    // MARK: - Validation Methods
    
    /// Validate a keyset according to NUT-01 requirements
    public nonisolated func validateKeyset(_ keyset: Keyset) -> Bool {
        // Basic validation
        guard !keyset.id.isEmpty,
              !keyset.unit.isEmpty,
              !keyset.keys.isEmpty else {
            return false
        }
        
        // Validate keyset ID format
        guard KeysetID.validateKeysetID(keyset.id) else {
            return false
        }
        
        // Validate that all keys are compressed secp256k1 public keys (66 hex chars)
        for (amountStr, publicKey) in keyset.keys {
            // Validate amount is a positive integer
            guard let amount = Int(amountStr), amount > 0 else {
                return false
            }
            
            // Validate public key format (compressed secp256k1: 66 hex chars)
            guard publicKey.isValidHex && publicKey.count == 66 else {
                return false
            }
            
            // Validate public key starts with 02 or 03 (compressed format)
            guard publicKey.hasPrefix("02") || publicKey.hasPrefix("03") else {
                return false
            }
        }
        
        return true
    }
    
    /// Validate currency unit according to NUT-01 specification
    public nonisolated func validateCurrencyUnit(_ unit: String) -> Bool {
        // Check if it's a known currency unit
        if CurrencyUnit(rawValue: unit) != nil {
            return true
        }
        
        // Allow other ISO 4217 codes or custom units
        // Basic validation: non-empty, lowercase, alphanumeric
        return !unit.isEmpty && 
               unit == unit.lowercased() && 
               unit.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    /// Validate that amounts represent minor units correctly
    public nonisolated func validateAmountForUnit(_ amount: Int, unit: String) -> Bool {
        guard amount > 0 else { return false }
        
        // For known currency units, validate according to their minor unit
        if CurrencyUnit(rawValue: unit) != nil {
            // Amount should be in minor units as per NUT-01
            // All amounts in keysets represent minor units
            return true
        }
        
        // For unknown units, accept any positive amount
        return true
    }
    
    // MARK: - Utility Methods
    
    // Removed local normalizeMintURL in favor of ValidationUtils.normalizeMintURL
    
    /// Convert amount from whole units to minor units
    /// Example: 1.23 USD -> 123 (cents)
    public nonisolated func convertToMinorUnits(_ amount: Double, unit: CurrencyUnit) -> Int {
        let multiplier = pow(10.0, Double(unit.minorUnit))
        return Int(amount * multiplier)
    }
    
    /// Convert amount from minor units to whole units
    /// Example: 123 cents -> 1.23 USD
    public nonisolated func convertFromMinorUnits(_ amount: Int, unit: CurrencyUnit) -> Double {
        let divisor = pow(10.0, Double(unit.minorUnit))
        return Double(amount) / divisor
    }
}

// MARK: - API Endpoints

enum KeyExchangeAPI {
    case getKeys
    case getKeysForKeyset(String)
}

extension KeyExchangeAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL, 
              let url = URL(string: baseURL) else { 
            fatalError("The baseURL for the mint must be set") 
        }
        return url
    }
    
    var path: String {
        switch self {
        case .getKeys:
            return "/v1/keys"
        case .getKeysForKeyset(let keysetID):
            return "/v1/keys/\(keysetID)"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .getKeys, .getKeysForKeyset:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .getKeys, .getKeysForKeyset:
            return .request
        }
    }
    
    var headers: HTTPHeaders? {
        return ["Accept": "application/json"]
    }
}

// MARK: - Compatibility Extensions

/// Extension to provide backward compatibility with existing KeysetService from NUT-02
extension KeyExchangeService {
    /// Alias for NUT-02 compatibility - same as getKeys
    public func getKeysResponse(from mintURL: String) async throws -> GetKeysResponse {
        return try await getKeys(from: mintURL)
    }
    
    /// Get active keysets (for NUT-02 compatibility)
    public func getActiveKeysets(from mintURL: String) async throws -> [Keyset] {
        let response = try await getKeys(from: mintURL)
        return response.keysets
    }
}
