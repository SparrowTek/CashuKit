//
//  KeychainSecureStore.swift
//  CashuKit
//
//  Secure storage implementation using Keychain for Apple platforms
//

import Foundation
import CoreCashu
import Vault

/// Keychain-based implementation of SecureStore for Apple platforms, backed by Vault.
///
/// Every item is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` in the
/// data-protection keychain. That protection class is load-bearing for a wallet: with
/// the pre-2.1 Vault (which couldn't set accessibility) the mnemonic and seed defaulted
/// to `kSecAttrAccessibleWhenUnlocked` — included in device backups and restorable onto
/// a *different* device, which for ecash also invites accidental two-device seed reuse
/// and double-spends.
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

    private let vault = Vault()
    private let serviceName: String
    private let accessGroup: String?
    private let accessControl: KeychainAccessControl?

    // MARK: - Initialization

    /// Initialize with optional access group for keychain sharing
    /// - Parameters:
    ///   - accessGroup: Optional keychain access group for app sharing
    ///   - accessControl: Optional user-presence gate (biometry / passcode) the keychain
    ///     evaluates on every read
    public init(
        accessGroup: String? = nil,
        accessControl: KeychainAccessControl? = nil
    ) {
        self.serviceName = KeychainConstants.serviceName
        self.accessGroup = accessGroup
        self.accessControl = accessControl
    }

    /// Wallet key material is deliberately **not** synchronizable: seeds in iCloud
    /// Keychain propagate to every signed-in device, and two devices spending from the
    /// same ecash seed double-spend against each other.
    @available(*, deprecated, message: "Ignored — wallet key material is ThisDeviceOnly by design.")
    public init(accessGroup: String? = nil, synchronizable: Bool) {
        self.init(accessGroup: accessGroup)
    }

    /// Test seam: an isolated keychain service so test runs never touch (or leak into)
    /// the production service, and parallel/aborted runs can't pollute each other.
    internal init(serviceName: String) {
        self.serviceName = serviceName
        self.accessGroup = nil
        self.accessControl = nil
    }

    // MARK: - Private Helpers

    private func configuration(account: String) -> KeychainConfiguration {
        KeychainConfiguration(
            serviceName: serviceName,
            accessGroup: accessGroup,
            accountName: account,
            accessibility: .afterFirstUnlockThisDeviceOnly,
            accessControl: accessControl
        )
    }

    private func saveItem(_ value: String, account: String) async throws {
        do {
            try await vault.save(value, configuration: configuration(account: account))
        } catch {
            throw SecureStoreError.storeFailed(error.localizedDescription)
        }
    }

    private func loadItem(account: String) async throws -> String? {
        do {
            return try await vault.read(configuration: configuration(account: account))
        } catch VaultError.itemNotFound {
            return nil
        } catch {
            throw SecureStoreError.retrievalFailed(error.localizedDescription)
        }
    }

    private func deleteItem(account: String) async throws {
        do {
            try await vault.delete(configuration: configuration(account: account))
        } catch VaultError.itemNotFound {
            return
        } catch {
            throw SecureStoreError.deletionFailed(error.localizedDescription)
        }
    }

    // MARK: - SecureStore Protocol Implementation

    // MARK: Mnemonic Operations

    public func saveMnemonic(_ mnemonic: SensitiveString) async throws {
        let plaintext = await mnemonic.withString { $0 }
        try await saveItem(plaintext, account: KeychainConstants.mnemonicAccount)
    }

    public func loadMnemonic() async throws -> SensitiveString? {
        guard let raw = try await loadItem(account: KeychainConstants.mnemonicAccount) else {
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
        try await saveItem(token, account: KeychainConstants.accessTokenPrefix + mintURL.absoluteString)
    }

    public func loadAccessToken(mintURL: URL) async throws -> String? {
        try await loadItem(account: KeychainConstants.accessTokenPrefix + mintURL.absoluteString)
    }

    public func deleteAccessToken(mintURL: URL) async throws {
        try await deleteItem(account: KeychainConstants.accessTokenPrefix + mintURL.absoluteString)
    }

    // MARK: Access Token List Operations

    public func saveAccessTokenList(_ tokens: [String], mintURL: URL) async throws {
        let data = try JSONEncoder().encode(tokens)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.invalidData
        }
        try await saveItem(jsonString, account: KeychainConstants.accessTokenListPrefix + mintURL.absoluteString)
    }

    public func loadAccessTokenList(mintURL: URL) async throws -> [String]? {
        guard let jsonString = try await loadItem(account: KeychainConstants.accessTokenListPrefix + mintURL.absoluteString) else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8) else {
            throw SecureStoreError.invalidData
        }
        return try JSONDecoder().decode([String].self, from: data)
    }

    public func deleteAccessTokenList(mintURL: URL) async throws {
        try await deleteItem(account: KeychainConstants.accessTokenListPrefix + mintURL.absoluteString)
    }

    // MARK: Utility Operations

    /// Removes every stored item — mnemonic, seed, and all access tokens for every mint
    /// (the whole keychain service). Errors propagate: a "wipe wallet" flow must never
    /// report success while the seed survives in the keychain.
    public func clearAll() async throws {
        do {
            try await vault.deleteAll(configuration: configuration(account: KeychainConstants.mnemonicAccount))
        } catch {
            throw SecureStoreError.deletionFailed(error.localizedDescription)
        }
    }

    public func hasStoredData() async throws -> Bool {
        if try await loadMnemonic() != nil {
            return true
        }
        return try await loadSeed() != nil
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

    /// iCloud-synced storage is not supported for wallet key material — see the
    /// deprecated initializer note.
    @available(*, deprecated, message: "Ignored — wallet key material is ThisDeviceOnly by design.")
    static var synced: KeychainSecureStore {
        KeychainSecureStore()
    }
}
