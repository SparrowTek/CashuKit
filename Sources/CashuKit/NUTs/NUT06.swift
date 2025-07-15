//
//  NUT06.swift
//  CashuKit
//
//  NUT-06: Mint information
//  https://github.com/cashubtc/nuts/blob/main/06.md
//

import Foundation

// MARK: - NUT-06: Mint information

/// NUT-06: Mint information
/// This NUT defines how wallets can retrieve information about a mint

// MARK: - Core Types

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
    
    /// Check if mint supports NUT-09 (Restore signatures)
    public func supportsRestoreSignatures() -> Bool {
        return isNUTSupported("9")
    }
    
    /// Check if mint supports NUT-10 (Spending conditions)
    public func supportsSpendingConditions() -> Bool {
        return isNUTSupported("10")
    }
}

// MARK: - NUT-05 settings structure

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

// MARK: - Capability Detection Types

/// Represents the capabilities of a Cashu mint
public struct MintCapabilities: Sendable {
    public let supportedNUTs: [String]
    public let supportsMinting: Bool
    public let supportsMelting: Bool
    public let supportsSwapping: Bool
    public let supportsStateCheck: Bool
    public let supportsRestoreSignatures: Bool
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
        supportsRestoreSignatures: Bool,
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
        self.supportsRestoreSignatures = supportsRestoreSignatures
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
        self.supportsRestoreSignatures = mintInfo.supportsRestoreSignatures()
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
        if supportsRestoreSignatures { features.append("Restore Signatures") }
        
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