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
    
    private func saveItem(_ data: String, account: String) async throws {
        let vault = Vault(configuration: createConfiguration(account: account))

        do {
            try await vault.save(data)
        } catch {
            throw SecureStoreError.storeFailed(error.localizedDescription)
        }
    }

    private func loadItem(account: String) async throws -> String? {
        let vault = Vault(configuration: createConfiguration(account: account))

        do {
            return try await vault.read()
        } catch VaultError.itemNotFound {
            return nil
        } catch {
            throw SecureStoreError.storeFailed(error.localizedDescription)
        }
    }

    private func deleteItem(account: String) async throws {
        let vault = Vault(configuration: createConfiguration(account: account))

        do {
            try await vault.delete()
        } catch VaultError.itemNotFound {
            return
        } catch {
            throw SecureStoreError.storeFailed(error.localizedDescription)
        }
    }
    
    // MARK: - SecureStore Protocol Implementation
    
    // MARK: Mnemonic Operations

    public func saveMnemonic(_ mnemonic: SensitiveString) async throws {
        let plaintext = mnemonic.withString { $0 }
        try await saveItem(plaintext, account: KeychainConstants.mnemonicAccount)
    }

    public func loadMnemonic() async throws -> SensitiveString? {
        guard let raw: String = try await loadItem(account: KeychainConstants.mnemonicAccount) else {
            return nil
        }
        return SensitiveString(raw)
    }

    public func deleteMnemonic() async throws {
        try await deleteItem(account: KeychainConstants.mnemonicAccount)
    }

    // MARK: Seed Operations

    public func saveSeed(_ seed: String) async throws {
        try await saveItem(seed, account: KeychainConstants.seedAccount)
    }

    public func loadSeed() async throws -> String? {
        try await loadItem(account: KeychainConstants.seedAccount)
    }

    public func deleteSeed() async throws {
        try await deleteItem(account: KeychainConstants.seedAccount)
    }

    // MARK: Access Token Operations

    public func saveAccessToken(_ token: String, mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenPrefix + mintURL.absoluteString
        try await saveItem(token, account: account)
    }

    public func loadAccessToken(mintURL: URL) async throws -> String? {
        let account = KeychainConstants.accessTokenPrefix + mintURL.absoluteString
        return try await loadItem(account: account)
    }

    public func deleteAccessToken(mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenPrefix + mintURL.absoluteString
        try await deleteItem(account: account)
    }

    // MARK: Access Token List Operations

    public func saveAccessTokenList(_ tokens: [String], mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenListPrefix + mintURL.absoluteString

        // Convert array to JSON string for storage
        let data = try JSONEncoder().encode(tokens)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.invalidData
        }

        try await saveItem(jsonString, account: account)
    }

    public func loadAccessTokenList(mintURL: URL) async throws -> [String]? {
        let account = KeychainConstants.accessTokenListPrefix + mintURL.absoluteString

        guard let jsonString = try await loadItem(account: account) else {
            return nil
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw SecureStoreError.invalidData
        }

        return try JSONDecoder().decode([String].self, from: data)
    }

    public func deleteAccessTokenList(mintURL: URL) async throws {
        let account = KeychainConstants.accessTokenListPrefix + mintURL.absoluteString
        try await deleteItem(account: account)
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
