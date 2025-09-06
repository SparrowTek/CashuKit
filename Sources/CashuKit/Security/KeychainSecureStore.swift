//
//  KeychainSecureStore.swift
//  CashuKit
//
//  Secure storage implementation using Keychain for Apple platforms
//

import Foundation
import CoreCashu
import Vault

/// Keychain-based implementation of SecureStore for Apple platforms
/// Provides secure storage for sensitive data like mnemonics, seeds, and access tokens
public actor KeychainSecureStore: SecureStore {
    
    // MARK: - Constants
    
    private enum KeychainConstants {
        static let serviceName = "com.cashukit.secure"
        static let mnemonicAccount = "wallet.mnemonic"
        static let seedAccount = "wallet.seed"
        static let accessTokenPrefix = "access.token."
        static let accessTokenListPrefix = "access.tokens."
    }
    
    // MARK: - Properties
    
    private let accessGroup: String?
    private let synchronizable: Bool
    
    // MARK: - Initialization
    
    /// Initialize with optional access group for keychain sharing
    /// - Parameters:
    ///   - accessGroup: Optional keychain access group for app sharing
    ///   - synchronizable: Whether to sync items via iCloud Keychain (default: false)
    public init(accessGroup: String? = nil, synchronizable: Bool = false) {
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
    }
    
    // MARK: - Private Helpers
    
    private func createConfiguration(account: String) -> KeychainConfiguration {
        KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: account
        )
    }
    
    private func saveItem(_ data: String, account: String) throws {
        let config = createConfiguration(account: account)
        
        do {
            try Vault.savePrivateKey(data, keychainConfiguration: config)
        } catch {
            throw SecureStoreError.storeFailed(error.localizedDescription)
        }
    }
    
    private func loadItem(account: String) throws -> String? {
        let config = createConfiguration(account: account)
        
        do {
            return try Vault.getPrivateKey(keychainConfiguration: config)
        } catch {
            // If item doesn't exist, return nil instead of throwing
            if (error as NSError).code == -25300 { // errSecItemNotFound
                return nil
            }
            // Vault might return nil for non-existent items
            return nil
        }
    }
    
    private func deleteItem(account: String) throws {
        let config = createConfiguration(account: account)
        
        do {
            try Vault.deletePrivateKey(keychainConfiguration: config)
        } catch {
            // Ignore if item doesn't exist
            if (error as NSError).code == -25300 { // errSecItemNotFound
                return
            }
            // Vault operations might fail silently for non-existent items
            return
        }
    }
    
    // MARK: - SecureStore Protocol Implementation
    
    // MARK: Mnemonic Operations
    
    public func saveMnemonic(_ mnemonic: String) async throws {
        try saveItem(mnemonic, account: KeychainConstants.mnemonicAccount)
    }
    
    public func loadMnemonic() async throws -> String? {
        try loadItem(account: KeychainConstants.mnemonicAccount)
    }
    
    public func deleteMnemonic() async throws {
        try deleteItem(account: KeychainConstants.mnemonicAccount)
    }
    
    // MARK: Seed Operations
    
    public func saveSeed(_ seed: String) async throws {
        try saveItem(seed, account: KeychainConstants.seedAccount)
    }
    
    public func loadSeed() async throws -> String? {
        try loadItem(account: KeychainConstants.seedAccount)
    }
    
    public func deleteSeed() async throws {
        try deleteItem(account: KeychainConstants.seedAccount)
    }
    
    // MARK: Access Token Operations
    
    public func saveAccessToken(_ token: String, mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenPrefix + mintURL.absoluteString
        try saveItem(token, account: account)
    }
    
    public func loadAccessToken(mintURL: URL) async throws -> String? {
        let account = KeychainConstants.accessTokenPrefix + mintURL.absoluteString
        return try loadItem(account: account)
    }
    
    public func deleteAccessToken(mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenPrefix + mintURL.absoluteString
        try deleteItem(account: account)
    }
    
    // MARK: Access Token List Operations
    
    public func saveAccessTokenList(_ tokens: [String], mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenListPrefix + mintURL.absoluteString
        
        // Convert array to JSON string for storage
        let data = try JSONEncoder().encode(tokens)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.invalidData
        }
        
        try saveItem(jsonString, account: account)
    }
    
    public func loadAccessTokenList(mintURL: URL) async throws -> [String]? {
        let account = KeychainConstants.accessTokenListPrefix + mintURL.absoluteString
        
        guard let jsonString = try loadItem(account: account) else {
            return nil
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw SecureStoreError.invalidData
        }
        
        return try JSONDecoder().decode([String].self, from: data)
    }
    
    public func deleteAccessTokenList(mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenListPrefix + mintURL.absoluteString
        try deleteItem(account: account)
    }
    
    // MARK: Utility Operations
    
    public func clearAll() async throws {
        // Clear all known items
        try? await deleteMnemonic()
        try? await deleteSeed()
        
        // Note: We can't easily clear all access tokens since we don't track all mint URLs
        // This would require maintaining a registry of all used mint URLs
    }
    
    public func hasStoredData() async throws -> Bool {
        let hasMnemonic = try await loadMnemonic() != nil
        let hasSeed = try await loadSeed() != nil
        return hasMnemonic || hasSeed
    }
}

// MARK: - Convenience Extensions

public extension KeychainSecureStore {
    /// Create a default keychain store with standard configuration
    static var `default`: KeychainSecureStore {
        KeychainSecureStore()
    }
    
    /// Create a keychain store with app group sharing
    static func shared(accessGroup: String) -> KeychainSecureStore {
        KeychainSecureStore(accessGroup: accessGroup)
    }
    
    /// Create a keychain store with iCloud sync enabled
    static var synced: KeychainSecureStore {
        KeychainSecureStore(synchronizable: true)
    }
}
