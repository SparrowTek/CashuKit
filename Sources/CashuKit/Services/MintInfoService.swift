//
//  MintInfoService.swift
//  CashuKit
//
//  Mint Information Service (not part of any specific NUT)
//  This provides general mint information and capabilities
//

import Foundation

// MARK: - Mint Information Service

/// Represents a value in the nuts dictionary that can be either a string or a dictionary
public enum NutValue: CashuCodabale {
    case string(String)
    case dictionary([String: AnyCodable])
    
    /// Get dictionary value if this is a dictionary case
    public var dictionaryValue: [String: Any]? {
        if case .dictionary(let dict) = self {
            return dict.mapValues { $0.anyValue }
        }
        return nil
    }
    
    /// Get string value if this is a string case
    public var stringValue: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let anyValue = try? container.decode(AnyCodable.self) {
            if let dictionary = anyValue.dictionaryValue {
                let codableDict = dictionary.compactMapValues { AnyCodable(anyValue: $0) }
                self = .dictionary(codableDict)
            } else {
                throw DecodingError.typeMismatch(NutValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode NutValue"))
            }
        } else {
            throw DecodingError.typeMismatch(NutValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode NutValue"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let string):
            try container.encode(string)
        case .dictionary(let dictionary):
            try container.encode(AnyCodable.dictionary(dictionary))
        }
    }
}


/// Mint information response structure
public struct MintInfo: CashuCodabale {
    public let name: String?
    public let pubkey: String
    public let version: String?
    public let description: String?
    public let descriptionLong: String?
    public let contact: [String]?
    public let nuts: [String: NutValue]?
    public let motd: String?
    public let parameter: MintParameters?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case pubkey
        case version
        case description
        case descriptionLong = "description_long"
        case contact
        case nuts
        case motd
        case parameter
    }
    
    public init(
        name: String? = nil,
        pubkey: String,
        version: String? = nil,
        description: String? = nil,
        descriptionLong: String? = nil,
        contact: [String]? = nil,
        nuts: [String: NutValue]? = nil,
        motd: String? = nil,
        parameter: MintParameters? = nil
    ) {
        self.name = name
        self.pubkey = pubkey
        self.version = version
        self.description = description
        self.descriptionLong = descriptionLong
        self.contact = contact
        self.nuts = nuts
        self.motd = motd
        self.parameter = parameter
    }
    
    /// Check if this mint supports a specific NUT
    public func supportsNUT(_ nut: String) -> Bool {
        return nuts?[nut] != nil
    }
    
    /// Get the version of a specific NUT if supported
    public func getNUTVersion(_ nut: String) -> String? {
        nuts?[nut]?.stringValue
    }
    
    /// Get all supported NUTs
    public func getSupportedNUTs() -> [String] {
        return nuts?.keys.sorted() ?? []
    }
    
    /// Check if mint supports basic operations (NUT-00, NUT-01, NUT-02)
    public func supportsBasicOperations() -> Bool {
        let basicNUTs = ["NUT-00", "NUT-01", "NUT-02"]
        return basicNUTs.allSatisfy { supportsNUT($0) }
    }
    
    /// Get NUT-04 settings if supported
    public func getNUT04Settings() -> NUT04Settings? {
        guard let nut04Data = nuts?["4"]?.dictionaryValue else { return nil }
        
        let disabled = nut04Data["disabled"] as? Bool ?? false
        
        guard let methodsData = nut04Data["methods"] as? [[String: Any]] else {
            return NUT04Settings(methods: [], disabled: disabled)
        }
        
        let methods = methodsData.compactMap { methodDict -> MintMethodSetting? in
            guard let method = methodDict["method"] as? String,
                  let unit = methodDict["unit"] as? String else {
                return nil
            }
            
            let minAmount = methodDict["min_amount"] as? Int
            let maxAmount = methodDict["max_amount"] as? Int
            let options = (methodDict["options"] as? [String: Any])?.compactMapValues { AnyCodable(anyValue: $0) }
            
            return MintMethodSetting(
                method: method,
                unit: unit,
                minAmount: minAmount,
                maxAmount: maxAmount,
                options: options
            )
        }
        
        return NUT04Settings(methods: methods, disabled: disabled)
    }
    
    /// Check if mint supports minting for specific method-unit pair
    public func supportsMinting(method: String, unit: String) -> Bool {
        guard let settings = getNUT04Settings() else { return false }
        return settings.isSupported(method: method, unit: unit)
    }
}

/// Mint parameters structure
public struct MintParameters: CashuCodabale {
    public let maxMessageLength: Int?
    public let supportedNUTs: [String]?
    
    public init(
        maxMessageLength: Int? = nil,
        supportedNUTs: [String]? = nil
    ) {
        self.maxMessageLength = maxMessageLength
        self.supportedNUTs = supportedNUTs
    }
    
    private enum CodingKeys: String, CodingKey {
        case maxMessageLength = "max_message_length"
        case supportedNUTs = "supported_nuts"
    }
}

@CashuActor
public struct MintInfoService: Sendable {
    private let router: NetworkRouter<MintInfoAPI>
    
    public init() async {
        self.router = NetworkRouter<MintInfoAPI>(decoder: .cashuDecoder)
        self.router.delegate = CashuEnvironment.current.routerDelegate
    }
    
    /// Get mint information from a mint URL.
    ///
    /// - parameter mintURL: (Required) The base URL of the mint (e.g., "https://mint.example.com")
    /// - returns: a `MintInfo` object
    public func getMintInfo(from mintURL: String) async throws -> MintInfo {
        // Validate and normalize the mint URL
        let normalizedURL = try normalizeMintURL(mintURL)
        
        // Set the base URL for this request
        CashuEnvironment.current.setup(baseURL: normalizedURL)
        
        return try await router.execute(.getMintInfo)
    }
    
    /// Check if a mint is available and responding.
    ///
    /// - parameter mintURL: (Required) The base URL of the mint
    /// - returns: True if mint is available, false otherwise
    public func isMintAvailable(_ mintURL: String) async -> Bool {
        do {
            _ = try await getMintInfo(from: mintURL)
            return true
        } catch {
            return false
        }
    }
    
    /// Get mint information with retry logic.
    ///
    /// - parameters:
    ///   - mintURL: (Required) The base URL of the mint
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - retryDelay: Delay between retries in seconds (default: 1.0)
    /// - returns: a `MintInfo` object
    public func getMintInfoWithRetry(
        from mintURL: String,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> MintInfo {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await getMintInfo(from: mintURL)
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? CashuError.mintUnavailable
    }
    
    // MARK: - Validation Methods (Non-isolated)
    
    /// Validate mint information
    /// - Parameter info: The mint information to validate
    /// - Returns: True if valid, false otherwise
    public nonisolated func validateMintInfo(_ info: MintInfo) -> Bool {
        // Basic validation
        guard !info.pubkey.isEmpty else { return false }
        
        // Validate pubkey format (should be a valid hex string)
        guard Data(hexString: info.pubkey) != nil else { return false }
        
        // Validate version if present
        if let version = info.version, version.isEmpty { return false }
        
        // Validate contact array if present
        if let contact = info.contact {
            for contactItem in contact {
                if contactItem.isEmpty { return false }
            }
        }
        
        // Validate nuts dictionary if present
        if let nuts = info.nuts {
            for (key, _) in nuts {
                if key.isEmpty { return false }
            }
        }
        
        return true
    }
    
    /// Validate mint URL format
    /// - Parameter mintURL: The URL to validate
    /// - Returns: True if valid, false otherwise
    public nonisolated func validateMintURL(_ mintURL: String) -> Bool {
        guard let url = URL(string: mintURL) else { return false }
        
        // Must have a scheme (http or https)
        guard let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return false
        }
        
        // Must have a host
        guard let host = url.host, !host.isEmpty else { return false }
        
        return true
    }
    
    // MARK: - Utility Methods (Non-isolated)
    
    /// Normalize a mint URL (add scheme if missing, remove trailing slash)
    /// - Parameter mintURL: The URL to normalize
    /// - Returns: Normalized URL
    private nonisolated func normalizeMintURL(_ mintURL: String) throws -> String {
        var normalizedURL = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme is present
        if !normalizedURL.contains("://") {
            normalizedURL = "https://" + normalizedURL
        }
        
        // Remove trailing slash
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        
        // Validate the normalized URL
        guard validateMintURL(normalizedURL) else {
            throw CashuError.invalidMintURL
        }
        
        return normalizedURL
    }
    
    /// Create a mock mint info for testing
    /// - Parameter pubkey: The mint's public key
    /// - Returns: Mock mint information
    public nonisolated func createMockMintInfo(pubkey: String) -> MintInfo {
        return MintInfo(
            name: "Test Mint",
            pubkey: pubkey,
            version: "1.0.0",
            description: "A test mint for development",
            descriptionLong: "This is a test mint used for development and testing purposes",
            contact: ["admin@testmint.com"],
            nuts: [
                "NUT-00": .string("1.0"),
                "NUT-01": .string("1.0"),
                "NUT-02": .string("1.0"),
                "NUT-03": .string("1.0"),
                "NUT-04": .dictionary([
                    "methods": .array([
                        .dictionary([
                            "method": .string("bolt11"),
                            "unit": .string("sat"),
                            "min_amount": .int(1),
                            "max_amount": .int(1000000)
                        ])
                    ]),
                    "disabled": .bool(false)
                ]),
                "NUT-05": .string("1.0")
            ],
            motd: "Welcome to Test Mint!",
            parameter: MintParameters(
                maxMessageLength: 1024,
                supportedNUTs: ["NUT-00", "NUT-01", "NUT-02", "NUT-03", "NUT-05"]
            )
        )
    }
    
    /// Compare two mint info objects for compatibility
    /// - Parameters:
    ///   - info1: First mint info
    ///   - info2: Second mint info
    /// - Returns: True if compatible, false otherwise
    public nonisolated func areMintsCompatible(_ info1: MintInfo, _ info2: MintInfo) -> Bool {
        // Check if both mints support basic operations
        guard info1.supportsBasicOperations() && info2.supportsBasicOperations() else {
            return false
        }
        
        // Check for common supported NUTs
        let nuts1 = Set(info1.getSupportedNUTs())
        let nuts2 = Set(info2.getSupportedNUTs())
        let commonNUTs = nuts1.intersection(nuts2)
        
        // Must have at least basic NUTs in common
        let basicNUTs = Set(["NUT-00", "NUT-01", "NUT-02"])
        return !basicNUTs.isDisjoint(with: commonNUTs)
    }
}

enum MintInfoAPI {
    case getMintInfo
}

extension MintInfoAPI: EndpointType {
    public var baseURL: URL {
        guard let baseURL = CashuEnvironment.current.baseURL, let url = URL(string: baseURL) else { fatalError("The baseURL for the mint must be set") }
        return url
    }
    
    var path: String {
        switch self {
        case .getMintInfo: "/info"
        }
    }
    
    var httpMethod: HTTPMethod {
        switch self {
        case .getMintInfo: .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .getMintInfo:
            return .request
        }
    }
    
    var headers: HTTPHeaders? {
        ["Accept": "application/json"]
    }
}
