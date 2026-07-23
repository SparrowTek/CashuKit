//
//  KeychainSecureStore.swift
//  CashuKit
//
//  Secure storage implementation using Keychain for Apple platforms
//

import Foundation
import CoreCashu
import Security

/// Keychain-based implementation of SecureStore for Apple platforms.
///
/// Delegates to CoreCashu's `KeychainSecureStore`, which stores every item with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and the data-protection keychain.
/// That protection class is load-bearing for a wallet: the previous implementation left
/// the accessibility attribute unset, so the mnemonic and seed defaulted to
/// `kSecAttrAccessibleWhenUnlocked` — included in device backups and restorable onto a
/// *different* device, which for ecash also invites accidental two-device seed reuse.
public actor KeychainSecureStore: SecureStore {

    // MARK: - Properties

    private let backing: CoreCashuKeychainSecureStore

    // MARK: - Initialization

    /// Initialize with optional access group for keychain sharing
    /// - Parameters:
    ///   - accessGroup: Optional keychain access group for app sharing
    ///   - accessControl: Optional access-control policy (biometry / passcode gating)
    public init(
        accessGroup: String? = nil,
        accessControl: CoreCashuKeychainSecureStore.Configuration.AccessControlPolicy? = nil
    ) {
        self.backing = CoreCashuKeychainSecureStore(
            configuration: .init(
                servicePrefix: "com.cashukit.secure",
                accessGroup: accessGroup,
                accessControl: accessControl
            )
        )
    }

    /// Wallet key material is deliberately **not** synchronizable: seeds in iCloud
    /// Keychain propagate to every signed-in device, and two devices spending from the
    /// same ecash seed double-spend against each other.
    @available(*, deprecated, message: "Ignored — wallet key material is ThisDeviceOnly by design.")
    public init(accessGroup: String? = nil, synchronizable: Bool) {
        self.init(accessGroup: accessGroup)
    }

    /// Test seam: an isolated keychain service prefix so test runs never touch (or leak
    /// into) the production service, and parallel/aborted runs can't pollute each other.
    internal init(servicePrefix: String) {
        self.backing = CoreCashuKeychainSecureStore(
            configuration: .init(servicePrefix: servicePrefix)
        )
    }

    // MARK: - SecureStore Protocol Implementation

    // MARK: Mnemonic Operations

    public func saveMnemonic(_ mnemonic: SensitiveString) async throws {
        try await backing.saveMnemonic(mnemonic)
    }

    public func loadMnemonic() async throws -> SensitiveString? {
        try await backing.loadMnemonic()
    }

    public func deleteMnemonic() async throws {
        try await backing.deleteMnemonic()
    }

    // MARK: Seed Operations

    public func saveSeed(_ seed: String) async throws {
        try await backing.saveSeed(seed)
    }

    public func loadSeed() async throws -> String? {
        try await backing.loadSeed()
    }

    public func deleteSeed() async throws {
        try await backing.deleteSeed()
    }

    // MARK: Access Token Operations

    public func saveAccessToken(_ token: String, mintURL: URL) async throws {
        try await backing.saveAccessToken(token, mintURL: mintURL)
    }

    public func loadAccessToken(mintURL: URL) async throws -> String? {
        try await backing.loadAccessToken(mintURL: mintURL)
    }

    public func deleteAccessToken(mintURL: URL) async throws {
        try await backing.deleteAccessToken(mintURL: mintURL)
    }

    // MARK: Access Token List Operations

    public func saveAccessTokenList(_ tokens: [String], mintURL: URL) async throws {
        try await backing.saveAccessTokenList(tokens, mintURL: mintURL)
    }

    public func loadAccessTokenList(mintURL: URL) async throws -> [String]? {
        try await backing.loadAccessTokenList(mintURL: mintURL)
    }

    public func deleteAccessTokenList(mintURL: URL) async throws {
        try await backing.deleteAccessTokenList(mintURL: mintURL)
    }

    // MARK: Utility Operations

    /// Removes every stored item, including access tokens. Errors propagate — a "wipe
    /// wallet" flow must never report success while the seed survives in the keychain.
    public func clearAll() async throws {
        try await backing.clearAll()
    }

    public func hasStoredData() async throws -> Bool {
        try await backing.hasStoredData()
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
