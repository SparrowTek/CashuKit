//
//  MintInfoService.swift
//  CashuKit
//
//  Mint Information Service (not part of any specific NUT)
//  This provides general mint information and capabilities
//

import Foundation

// MARK: - Mint Capabilities

/// Represents the capabilities of a Cashu mint
public struct MintCapabilities: Sendable {
    public let supportedNUTs: [String]
    public let supportsMinting: Bool
    public let supportsMelting: Bool
    public let supportsSwapping: Bool
    public let supportsStateCheck: Bool
    public let mintMethods: [String]
    public let meltMethods: [String]
    public let supportedUnits: [String]
    public let hasContactInfo: Bool
    public let hasTermsOfService: Bool
    public let hasIcon: Bool
    public let messageOfTheDay: String?
    
    public init(
        supportedNUTs: [String],
        supportsMinting: Bool,
        supportsMelting: Bool,
        supportsSwapping: Bool,
        supportsStateCheck: Bool,
        mintMethods: [String],
        meltMethods: [String],
        supportedUnits: [String],
        hasContactInfo: Bool,
        hasTermsOfService: Bool,
        hasIcon: Bool,
        messageOfTheDay: String?
    ) {
        self.supportedNUTs = supportedNUTs
        self.supportsMinting = supportsMinting
        self.supportsMelting = supportsMelting
        self.supportsSwapping = supportsSwapping
        self.supportsStateCheck = supportsStateCheck
        self.mintMethods = mintMethods
        self.meltMethods = meltMethods
        self.supportedUnits = supportedUnits
        self.hasContactInfo = hasContactInfo
        self.hasTermsOfService = hasTermsOfService
        self.hasIcon = hasIcon
        self.messageOfTheDay = messageOfTheDay
    }
    
    /// Initialize from MintInfo
    public init(from mintInfo: MintInfo) {
        self.supportedNUTs = mintInfo.getSupportedNUTs()
        self.supportsMinting = mintInfo.getNUT04Settings() != nil
        self.supportsMelting = mintInfo.getNUT05Settings() != nil
        self.supportsSwapping = mintInfo.isNUTSupported("3")
        self.supportsStateCheck = mintInfo.isNUTSupported("7")
        self.mintMethods = mintInfo.getNUT04Settings()?.supportedMethods ?? []
        self.meltMethods = mintInfo.getNUT05Settings()?.supportedMethods ?? []
        
        var units: Set<String> = []
        if let nut04 = mintInfo.getNUT04Settings() {
            units.formUnion(nut04.supportedUnits)
        }
        if let nut05 = mintInfo.getNUT05Settings() {
            units.formUnion(nut05.supportedUnits)
        }
        self.supportedUnits = Array(units).sorted()
        
        self.hasContactInfo = !(mintInfo.contact?.isEmpty ?? true)
        self.hasTermsOfService = !mintInfo.tosURL.isNilOrEmpty
        self.hasIcon = !mintInfo.iconURL.isNilOrEmpty
        self.messageOfTheDay = mintInfo.motd
    }
    
    /// Check if mint supports basic wallet operations
    public var supportsBasicWalletOperations: Bool {
        return supportsMinting && supportsMelting && supportsSwapping
    }
    
    /// Get a summary of mint capabilities
    public var summary: String {
        var features: [String] = []
        
        if supportsMinting { features.append("Minting") }
        if supportsMelting { features.append("Melting") }
        if supportsSwapping { features.append("Swapping") }
        if supportsStateCheck { features.append("State Check") }
        
        return features.joined(separator: ", ")
    }
}

// MARK: - Metadata Support Types

/// Structured mint metadata
public struct MintMetadata: Sendable {
    public let name: String?
    public let description: String?
    public let longDescription: String?
    public let iconURL: String?
    public let tosURL: String?
    public let contactInfo: [String: String]
    public let urls: [MintURL]
    public let versionInfo: VersionInfo?
    public let operationalStatus: String?
    public let lastUpdated: Date?
    
    public init(from mintInfo: MintInfo) {
        self.name = mintInfo.name
        self.description = mintInfo.description
        self.longDescription = mintInfo.descriptionLong
        self.iconURL = mintInfo.iconURL
        self.tosURL = mintInfo.tosURL
        
        // Parse contact info
        var contacts: [String: String] = [:]
        if let contactArray = mintInfo.contact {
            for contact in contactArray {
                contacts[contact.method] = contact.info
            }
        }
        self.contactInfo = contacts
        
        // Parse URLs
        if let urlStrings = mintInfo.urls {
            self.urls = urlStrings.compactMap { urlString in
                guard URL(string: urlString) != nil else { return nil }
                
                let type: MintURLType
                if urlString.contains(".onion") {
                    type = .tor
                } else if urlString.hasPrefix("https://") {
                    type = .https
                } else if urlString.hasPrefix("http://") {
                    type = .http
                } else {
                    type = .unknown
                }
                
                return MintURL(url: urlString, type: type)
            }
        } else {
            self.urls = []
        }
        
        // Parse version info
        if let version = mintInfo.version {
            self.versionInfo = VersionInfo(from: version)
        } else {
            self.versionInfo = nil
        }
        
        self.operationalStatus = mintInfo.motd
        self.lastUpdated = mintInfo.serverTime
    }
}

/// Version information parser
public struct VersionInfo: Sendable {
    public let implementation: String?
    public let version: String?
    public let rawVersion: String
    
    public init(from versionString: String) {
        self.rawVersion = versionString
        
        // Parse format like "Nutshell/0.15.0"
        let components = versionString.split(separator: "/")
        if components.count == 2 {
            self.implementation = String(components[0])
            self.version = String(components[1])
        } else {
            self.implementation = nil
            self.version = versionString
        }
    }
    
    /// Check if this version is newer than another
    public func isNewer(than other: VersionInfo) -> Bool {
        guard let thisVersion = self.version,
              let otherVersion = other.version else {
            return false
        }
        
        return compareVersions(thisVersion, otherVersion) > 0
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value != v2Value {
                return v1Value - v2Value
            }
        }
        
        return 0
    }
}

/// Mint URL with type information
public struct MintURL: Sendable {
    public let url: String
    public let type: MintURLType
    
    public init(url: String, type: MintURLType) {
        self.url = url
        self.type = type
    }
}

/// Type of mint URL
public enum MintURLType: String, CaseIterable, Sendable {
    case https = "https"
    case http = "http"
    case tor = "tor"
    case unknown = "unknown"
    
    /// Priority for URL selection (higher is better)
    public var priority: Int {
        switch self {
        case .https: return 3
        case .tor: return 2
        case .http: return 1
        case .unknown: return 0
        }
    }
}

/// NUT configuration information
public struct NUTConfiguration: Sendable {
    public let version: String?
    public let settings: [String: AnyCodable]?
    public let enabled: Bool
    
    public init(version: String?, settings: [String: Any]?, enabled: Bool) {
        self.version = version
        if let settings = settings {
            self.settings = settings.compactMapValues { AnyCodable(anyValue: $0) }
        } else {
            self.settings = nil
        }
        self.enabled = enabled
    }
}

/// Mint operational status
public struct MintOperationalStatus: Sendable {
    public let isOperational: Bool
    public let lastUpdated: Date
    public let messageOfTheDay: String?
    public let supportedOperations: String
    public let hasTermsOfService: Bool
    public let hasContactInfo: Bool
    
    public init(
        isOperational: Bool,
        lastUpdated: Date,
        messageOfTheDay: String?,
        supportedOperations: String,
        hasTermsOfService: Bool,
        hasContactInfo: Bool
    ) {
        self.isOperational = isOperational
        self.lastUpdated = lastUpdated
        self.messageOfTheDay = messageOfTheDay
        self.supportedOperations = supportedOperations
        self.hasTermsOfService = hasTermsOfService
        self.hasContactInfo = hasContactInfo
    }
    
    /// Human-readable status description
    public var statusDescription: String {
        if isOperational {
            return "Operational"
        } else {
            return "Limited functionality"
        }
    }
}

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


/// Contact information for mint operators
public struct MintContact: CashuCodabale {
    public let method: String
    public let info: String
    
    public init(method: String, info: String) {
        self.method = method
        self.info = info
    }
}

/// Mint information response structure (NUT-06)
public struct MintInfo: CashuCodabale {
    public let name: String?
    public let pubkey: String?
    public let version: String?
    public let description: String?
    public let descriptionLong: String?
    public let contact: [MintContact]?
    public let nuts: [String: NutValue]?
    public let motd: String?
    public let iconURL: String?
    public let urls: [String]?
    public let time: Int?
    public let tosURL: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case pubkey
        case version
        case description
        case descriptionLong = "description_long"
        case contact
        case nuts
        case motd
        case iconURL = "icon_url"
        case urls
        case time
        case tosURL = "tos_url"
    }
    
    public init(
        name: String? = nil,
        pubkey: String? = nil,
        version: String? = nil,
        description: String? = nil,
        descriptionLong: String? = nil,
        contact: [MintContact]? = nil,
        nuts: [String: NutValue]? = nil,
        motd: String? = nil,
        iconURL: String? = nil,
        urls: [String]? = nil,
        time: Int? = nil,
        tosURL: String? = nil
    ) {
        self.name = name
        self.pubkey = pubkey
        self.version = version
        self.description = description
        self.descriptionLong = descriptionLong
        self.contact = contact
        self.nuts = nuts
        self.motd = motd
        self.iconURL = iconURL
        self.urls = urls
        self.time = time
        self.tosURL = tosURL
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
    
    /// Get NUT-05 settings if supported
    public func getNUT05Settings() -> NUT05Settings? {
        guard let nut05Data = nuts?["5"]?.dictionaryValue else { return nil }
        
        let disabled = nut05Data["disabled"] as? Bool ?? false
        
        guard let methodsData = nut05Data["methods"] as? [[String: Any]] else {
            return NUT05Settings(methods: [], disabled: disabled)
        }
        
        let methods = methodsData.compactMap { methodDict -> MeltMethodSetting? in
            guard let method = methodDict["method"] as? String,
                  let unit = methodDict["unit"] as? String else {
                return nil
            }
            
            let minAmount = methodDict["min_amount"] as? Int
            let maxAmount = methodDict["max_amount"] as? Int
            let options = (methodDict["options"] as? [String: Any])?.compactMapValues { AnyCodable(anyValue: $0) }
            
            return MeltMethodSetting(
                method: method,
                unit: unit,
                minAmount: minAmount,
                maxAmount: maxAmount,
                options: options
            )
        }
        
        return NUT05Settings(methods: methods, disabled: disabled)
    }
    
    /// Check if a specific NUT is supported with boolean response
    public func isNUTSupported(_ nut: String) -> Bool {
        guard let nutData = nuts?[nut]?.dictionaryValue else {
            return nuts?[nut]?.stringValue != nil
        }
        
        return nutData["supported"] as? Bool ?? true
    }
    
    /// Get all NUTs with their status
    public func getAllNUTsStatus() -> [String: Bool] {
        var status: [String: Bool] = [:]
        
        nuts?.forEach { (key, value) in
            if let dict = value.dictionaryValue {
                status[key] = dict["supported"] as? Bool ?? true
            } else {
                status[key] = true
            }
        }
        
        return status
    }
    
    /// Get the current server time if available
    public var serverTime: Date? {
        guard let time = time else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time))
    }
    
    /// Check if mint information is valid according to NUT-06
    public func isValid() -> Bool {
        return !name.isNilOrEmpty && !pubkey.isNilOrEmpty
    }
    
    /// Check if mint supports minting for specific method-unit pair
    public func supportsMinting(method: String, unit: String) -> Bool {
        guard let settings = getNUT04Settings() else { return false }
        return settings.isSupported(method: method, unit: unit)
    }
}


/// NUT-05 settings structure
public struct NUT05Settings: CashuCodabale {
    public let methods: [MeltMethodSetting]
    public let disabled: Bool
    
    public init(methods: [MeltMethodSetting], disabled: Bool = false) {
        self.methods = methods
        self.disabled = disabled
    }
    
    /// Get settings for specific method-unit pair
    public func getMethodSetting(method: String, unit: String) -> MeltMethodSetting? {
        return methods.first { $0.method == method && $0.unit == unit }
    }
    
    /// Check if method-unit pair is supported
    public func isSupported(method: String, unit: String) -> Bool {
        return !disabled && getMethodSetting(method: method, unit: unit) != nil
    }
    
    /// Get all supported methods
    public var supportedMethods: [String] {
        return Array(Set(methods.map { $0.method }))
    }
    
    /// Get all supported units
    public var supportedUnits: [String] {
        return Array(Set(methods.map { $0.unit }))
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
        // NUT-06 requires either name or pubkey to be present
        guard !info.name.isNilOrEmpty || !info.pubkey.isNilOrEmpty else { return false }
        
        // Validate pubkey format if present (should be a valid hex string)
        if let pubkey = info.pubkey, !pubkey.isEmpty {
            guard Data(hexString: pubkey) != nil else { return false }
        }
        
        // Validate version if present
        if let version = info.version, version.isEmpty { return false }
        
        // Validate contact array if present
        if let contact = info.contact {
            for contactItem in contact {
                if contactItem.method.isEmpty || contactItem.info.isEmpty { return false }
            }
        }
        
        // Validate nuts dictionary if present
        if let nuts = info.nuts {
            for (key, _) in nuts {
                if key.isEmpty { return false }
            }
        }
        
        // Validate URLs if present
        if let urls = info.urls {
            for url in urls {
                guard !url.isEmpty, URL(string: url) != nil else { return false }
            }
        }
        
        // Validate icon URL if present
        if let iconURL = info.iconURL, !iconURL.isEmpty {
            guard URL(string: iconURL) != nil else { return false }
        }
        
        // Validate TOS URL if present
        if let tosURL = info.tosURL, !tosURL.isEmpty {
            guard URL(string: tosURL) != nil else { return false }
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
            version: "Nutshell/0.15.0",
            description: "A test mint for development",
            descriptionLong: "This is a test mint used for development and testing purposes",
            contact: [
                MintContact(method: "email", info: "admin@testmint.com"),
                MintContact(method: "twitter", info: "@testmint")
            ],
            nuts: [
                "4": .dictionary([
                    "methods": .array([
                        .dictionary([
                            "method": .string("bolt11"),
                            "unit": .string("sat"),
                            "min_amount": .int(0),
                            "max_amount": .int(10000)
                        ])
                    ]),
                    "disabled": .bool(false)
                ]),
                "5": .dictionary([
                    "methods": .array([
                        .dictionary([
                            "method": .string("bolt11"),
                            "unit": .string("sat"),
                            "min_amount": .int(100),
                            "max_amount": .int(10000)
                        ])
                    ]),
                    "disabled": .bool(false)
                ]),
                "7": .dictionary(["supported": .bool(true)]),
                "8": .dictionary(["supported": .bool(true)]),
                "9": .dictionary(["supported": .bool(true)]),
                "10": .dictionary(["supported": .bool(true)]),
                "12": .dictionary(["supported": .bool(true)])
            ],
            motd: "Welcome to Test Mint!",
            iconURL: "https://testmint.com/icon.jpg",
            urls: ["https://testmint.com"],
            time: Int(Date().timeIntervalSince1970),
            tosURL: "https://testmint.com/tos"
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
    
    // MARK: - Capability Detection Methods
    
    /// Detect capabilities of a mint based on mint info
    /// - Parameter mintURL: The mint URL to analyze
    /// - Returns: MintCapabilities object with detected capabilities
    public func detectMintCapabilities(from mintURL: String) async throws -> MintCapabilities {
        let mintInfo = try await getMintInfo(from: mintURL)
        return MintCapabilities(from: mintInfo)
    }
    
    /// Get supported payment methods for minting
    /// - Parameter mintURL: The mint URL
    /// - Returns: Array of supported payment methods for minting
    public func getSupportedMintMethods(from mintURL: String) async throws -> [String] {
        let mintInfo = try await getMintInfo(from: mintURL)
        return mintInfo.getNUT04Settings()?.supportedMethods ?? []
    }
    
    /// Get supported payment methods for melting
    /// - Parameter mintURL: The mint URL
    /// - Returns: Array of supported payment methods for melting
    public func getSupportedMeltMethods(from mintURL: String) async throws -> [String] {
        let mintInfo = try await getMintInfo(from: mintURL)
        return mintInfo.getNUT05Settings()?.supportedMethods ?? []
    }
    
    /// Check if mint supports swapping (send/receive)
    /// - Parameter mintURL: The mint URL
    /// - Returns: True if swap operations are supported
    public func supportsSwap(at mintURL: String) async throws -> Bool {
        let mintInfo = try await getMintInfo(from: mintURL)
        return mintInfo.isNUTSupported("3")
    }
    
    /// Check if mint supports token state checking
    /// - Parameter mintURL: The mint URL
    /// - Returns: True if token state checking is supported
    public func supportsTokenStateCheck(at mintURL: String) async throws -> Bool {
        let mintInfo = try await getMintInfo(from: mintURL)
        return mintInfo.isNUTSupported("7")
    }
    
    /// Get maximum transaction amount for a method-unit pair
    /// - Parameters:
    ///   - method: Payment method
    ///   - unit: Currency unit
    ///   - mintURL: The mint URL
    /// - Returns: Maximum amount or nil if no limit
    public func getMaximumAmount(for method: String, unit: String, at mintURL: String) async throws -> Int? {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        // Check both mint and melt settings
        if let mintSettings = mintInfo.getNUT04Settings() {
            if let methodSetting = mintSettings.getMethodSetting(method: method, unit: unit) {
                return methodSetting.maxAmount
            }
        }
        
        if let meltSettings = mintInfo.getNUT05Settings() {
            if let methodSetting = meltSettings.getMethodSetting(method: method, unit: unit) {
                return methodSetting.maxAmount
            }
        }
        
        return nil
    }
    
    /// Get minimum transaction amount for a method-unit pair
    /// - Parameters:
    ///   - method: Payment method
    ///   - unit: Currency unit
    ///   - mintURL: The mint URL
    /// - Returns: Minimum amount or nil if no limit
    public func getMinimumAmount(for method: String, unit: String, at mintURL: String) async throws -> Int? {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        // Check both mint and melt settings
        if let mintSettings = mintInfo.getNUT04Settings() {
            if let methodSetting = mintSettings.getMethodSetting(method: method, unit: unit) {
                return methodSetting.minAmount
            }
        }
        
        if let meltSettings = mintInfo.getNUT05Settings() {
            if let methodSetting = meltSettings.getMethodSetting(method: method, unit: unit) {
                return methodSetting.minAmount
            }
        }
        
        return nil
    }
    
    // MARK: - Metadata Parsing Methods
    
    /// Parse mint metadata into structured format
    /// - Parameter mintURL: The mint URL to analyze
    /// - Returns: MintMetadata object with parsed information
    public func parseMintMetadata(from mintURL: String) async throws -> MintMetadata {
        let mintInfo = try await getMintInfo(from: mintURL)
        return MintMetadata(from: mintInfo)
    }
    
    /// Extract contact information in a structured format
    /// - Parameter mintURL: The mint URL
    /// - Returns: Dictionary of contact methods and their details
    public func parseContactInfo(from mintURL: String) async throws -> [String: String] {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        guard let contacts = mintInfo.contact else {
            return [:]
        }
        
        var contactDict: [String: String] = [:]
        for contact in contacts {
            contactDict[contact.method] = contact.info
        }
        
        return contactDict
    }
    
    /// Parse version information
    /// - Parameter mintURL: The mint URL
    /// - Returns: VersionInfo object with parsed version details
    public func parseVersionInfo(from mintURL: String) async throws -> VersionInfo? {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        guard let version = mintInfo.version else {
            return nil
        }
        
        return VersionInfo(from: version)
    }
    
    /// Parse available URLs for the mint
    /// - Parameter mintURL: The mint URL
    /// - Returns: Array of mint URLs with their types
    public func parseAvailableURLs(from mintURL: String) async throws -> [MintURL] {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        guard let urls = mintInfo.urls else {
            return []
        }
        
        return urls.compactMap { urlString in
            guard let url = URL(string: urlString) else { return nil }
            
            let type: MintURLType
            if urlString.contains(".onion") {
                type = .tor
            } else if url.scheme == "https" {
                type = .https
            } else if url.scheme == "http" {
                type = .http
            } else {
                type = .unknown
            }
            
            return MintURL(url: urlString, type: type)
        }
    }
    
    /// Parse supported NUTs with their configurations
    /// - Parameter mintURL: The mint URL
    /// - Returns: Dictionary of NUT names and their configurations
    public func parseNUTConfigurations(from mintURL: String) async throws -> [String: NUTConfiguration] {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        guard let nuts = mintInfo.nuts else {
            return [:]
        }
        
        var configurations: [String: NUTConfiguration] = [:]
        
        for (nutKey, nutValue) in nuts {
            let config: NUTConfiguration
            
            if let stringValue = nutValue.stringValue {
                config = NUTConfiguration(version: stringValue, settings: nil, enabled: true)
            } else if let dictValue = nutValue.dictionaryValue {
                let enabled = !(dictValue["disabled"] as? Bool ?? false)
                let supported = dictValue["supported"] as? Bool ?? true
                let version = dictValue["version"] as? String
                
                config = NUTConfiguration(
                    version: version,
                    settings: dictValue,
                    enabled: enabled && supported
                )
            } else {
                config = NUTConfiguration(version: nil, settings: nil, enabled: false)
            }
            
            configurations[nutKey] = config
        }
        
        return configurations
    }
    
    /// Get mint operational status information
    /// - Parameter mintURL: The mint URL
    /// - Returns: MintOperationalStatus with current status
    public func getMintOperationalStatus(from mintURL: String) async throws -> MintOperationalStatus {
        let mintInfo = try await getMintInfo(from: mintURL)
        
        let capabilities = MintCapabilities(from: mintInfo)
        let isOperational = capabilities.supportsBasicWalletOperations
        
        let lastUpdated = mintInfo.serverTime ?? Date()
        
        return MintOperationalStatus(
            isOperational: isOperational,
            lastUpdated: lastUpdated,
            messageOfTheDay: mintInfo.motd,
            supportedOperations: capabilities.summary,
            hasTermsOfService: capabilities.hasTermsOfService,
            hasContactInfo: capabilities.hasContactInfo
        )
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
        case .getMintInfo: "/v1/info"
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
