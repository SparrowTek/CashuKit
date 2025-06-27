//
//  NUT01_MintInformation.swift
//  CashuKit
//
//  NUT-01: Mint Information
//  https://github.com/cashubtc/nuts/blob/main/01.md
//

import Foundation

// MARK: - NUT-01: Mint Information

/// NUT-01: Mint Information
/// This NUT defines the mint information endpoint and response format
public struct NUT01_MintInformation {
    
    /// Mint information response structure
    public struct MintInfo: Codable, Sendable {
        public let name: String?
        public let pubkey: String
        public let version: String?
        public let description: String?
        public let descriptionLong: String?
        public let contact: [String]?
        public let nuts: [String: String]?
        public let motd: String?
        public let parameter: MintParameters?
        
        public init(
            name: String? = nil,
            pubkey: String,
            version: String? = nil,
            description: String? = nil,
            descriptionLong: String? = nil,
            contact: [String]? = nil,
            nuts: [String: String]? = nil,
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
    }
    
    /// Mint parameters structure
    public struct MintParameters: Codable, Sendable {
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
    
    /// Get mint information from a mint URL
    public static func getMintInfo(from mintURL: String) async throws -> MintInfo {
        // TODO: Implement actual HTTP request to /info endpoint
        throw CashuError.nutNotImplemented("NUT-01")
    }
    
    /// Validate mint information
    public static func validateMintInfo(_ info: MintInfo) -> Bool {
        // Basic validation
        guard !info.pubkey.isEmpty else { return false }
        return true
    }
} 