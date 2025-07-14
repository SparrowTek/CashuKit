//
//  MintInfoService.swift
//  CashuKit
//
//  NUT-06: Mint Information Service
//  https://github.com/cashubtc/nuts/blob/main/06.md
//

import Foundation



// MARK: - Mint Information Service (NUT-06)

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
        let normalizedURL = try ValidationUtils.normalizeMintURL(mintURL)
        
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
        return ValidationUtils.validateMintURL(mintURL).isValid
    }
    
    // MARK: - Utility Methods (Non-isolated)
    
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
