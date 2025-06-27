//
//  NUT02_MintKeyManagement.swift
//  CashuKit
//
//  NUT-02: Mint Key Management
//  https://github.com/cashubtc/nuts/blob/main/02.md
//

import Foundation

// MARK: - NUT-02: Mint Key Management

/// NUT-02: Mint Key Management
/// This NUT defines how mints manage their keys for different amounts
public struct NUT02_MintKeyManagement {
    
    /// Mint keys response structure
    public struct MintKeys: Codable, Sendable {
        public let keysets: [Keyset]
        
        public init(keysets: [Keyset]) {
            self.keysets = keysets
        }
    }
    
    /// Keyset structure
    public struct Keyset: Codable, Sendable {
        public let id: String
        public let unit: String
        public let keys: [String: String] // amount -> public key
        
        public init(id: String, unit: String, keys: [String: String]) {
            self.id = id
            self.unit = unit
            self.keys = keys
        }
    }
    
    /// Get mint keys from a mint URL
    public static func getMintKeys(from mintURL: String) async throws -> MintKeys {
        // TODO: Implement actual HTTP request to /keys endpoint
        throw CashuError.nutNotImplemented("NUT-02")
    }
    
    /// Validate mint keys
    public static func validateMintKeys(_ keys: MintKeys) -> Bool {
        // Basic validation
        guard !keys.keysets.isEmpty else { return false }
        
        for keyset in keys.keysets {
            guard !keyset.id.isEmpty,
                  !keyset.unit.isEmpty,
                  !keyset.keys.isEmpty else {
                return false
            }
        }
        
        return true
    }
} 