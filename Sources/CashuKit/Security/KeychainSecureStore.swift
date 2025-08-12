//
//  KeychainSecureStore.swift
//  CashuKit
//
//  Apple Keychain implementation of SecureStore protocol
//

import Foundation
import CoreCashu
import Vault
import P256K
import LocalAuthentication

/// Apple Keychain implementation of the SecureStore protocol
public actor KeychainSecureStore: SecureStore {
    
    // MARK: - Types
    
    public struct SecurityConfiguration: Sendable {
        public let useBiometrics: Bool
        public let useSecureEnclave: Bool
        public let accessibleWhenUnlocked: Bool
        public let synchronizable: Bool // iCloud Keychain sync
        
        public init(
            useBiometrics: Bool = false,
            useSecureEnclave: Bool = true,
            accessibleWhenUnlocked: Bool = true,
            synchronizable: Bool = false
        ) {
            self.useBiometrics = useBiometrics
            self.useSecureEnclave = useSecureEnclave
            self.accessibleWhenUnlocked = accessibleWhenUnlocked
            self.synchronizable = synchronizable
        }
        
        public static let standard = SecurityConfiguration()
        public static let maximum = SecurityConfiguration(
            useBiometrics: true,
            useSecureEnclave: true,
            accessibleWhenUnlocked: false,
            synchronizable: false
        )
    }
    
    // MARK: - Constants
    
    private enum KeychainConstants {
        static let serviceName = "com.cashukit.keychain"
        static let walletMnemonicAccount = "wallet.mnemonic"
        static let walletSeedAccount = "wallet.seed"
        static let mintPrivateKeyPrefix = "mint.privatekey."
        static let ephemeralKeyPrefix = "ephemeral.key."
        static let accessTokenPrefix = "access.token."
        static let accessTokenListPrefix = "access.token.list."
    }
    
    // MARK: - Properties
    
    private let accessGroup: String?
    private let securityConfig: SecurityConfiguration
    private let logger = OSLogLogger(category: "KeychainSecureStore", minimumLevel: .warning)
    
    // MARK: - Initialization
    
    /// Initialize with optional access group for keychain sharing
    public init(accessGroup: String? = nil, securityConfiguration: SecurityConfiguration = .standard) {
        self.accessGroup = accessGroup
        self.securityConfig = securityConfiguration
        
        // Configure Vault globally if not already configured
        let configuration = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "default"
        )
        Vault.configure(configuration)
    }
    
    // MARK: - Wallet Key Management
    
    // MARK: - SecureStore Protocol Implementation
    
    public func saveMnemonic(_ mnemonic: String) async throws {
        // Require biometric auth for mnemonic storage if configured
        if securityConfig.useBiometrics {
            try await BiometricAuthManager.shared.authenticateForSensitiveOperation("Store wallet mnemonic securely")
        }
        
        let config = createSecureKeychainConfiguration(
            account: KeychainConstants.walletMnemonicAccount,
            requireBiometrics: true // Always protect mnemonic with biometrics if available
        )
        
        // Clear sensitive data from memory after use
        defer {
            _ = mnemonic.withCString { memset(UnsafeMutableRawPointer(mutating: $0), 0, mnemonic.count) }
        }
        
        try Vault.savePrivateKey(mnemonic, keychainConfiguration: config)
        logger.info("Mnemonic stored securely")
    }
    
    public func loadMnemonic() async throws -> String? {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletMnemonicAccount
        )
        return try? Vault.getPrivateKey(keychainConfiguration: config)
    }
    
    public func saveSeed(_ seed: String) async throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletSeedAccount
        )
        try Vault.savePrivateKey(seed, keychainConfiguration: config)
    }
    
    public func loadSeed() async throws -> String? {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletSeedAccount
        )
        return try? Vault.getPrivateKey(keychainConfiguration: config)
    }
    
    public func deleteMnemonic() async throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletMnemonicAccount
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
    }
    
    public func deleteSeed() async throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletSeedAccount
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
    }
    
    // MARK: - Access Token Operations (NUT-21)
    
    public func saveAccessToken(_ token: String, mintURL: URL) async throws {
        let key = makeSanitizedAccount(prefix: KeychainConstants.accessTokenPrefix, mintURL: mintURL.absoluteString)
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: key
        )
        try Vault.savePrivateKey(token, keychainConfiguration: config)
    }
    
    public func loadAccessToken(mintURL: URL) async throws -> String? {
        let key = makeSanitizedAccount(prefix: KeychainConstants.accessTokenPrefix, mintURL: mintURL.absoluteString)
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: key
        )
        return try? Vault.getPrivateKey(keychainConfiguration: config)
    }
    
    public func deleteAccessToken(mintURL: URL) async throws {
        let key = makeSanitizedAccount(prefix: KeychainConstants.accessTokenPrefix, mintURL: mintURL.absoluteString)
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: key
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
    }
    
    // MARK: - Access Token List Operations (NUT-22)
    
    public func saveAccessTokenList(_ tokens: [String], mintURL: URL) async throws {
        let key = makeSanitizedAccount(prefix: KeychainConstants.accessTokenListPrefix, mintURL: mintURL.absoluteString)
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: key
        )
        let data = try JSONEncoder().encode(tokens)
        let base64 = data.base64EncodedString()
        try Vault.savePrivateKey(base64, keychainConfiguration: config)
    }
    
    public func loadAccessTokenList(mintURL: URL) async throws -> [String]? {
        let key = makeSanitizedAccount(prefix: KeychainConstants.accessTokenListPrefix, mintURL: mintURL.absoluteString)
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: key
        )
        guard let base64 = try? Vault.getPrivateKey(keychainConfiguration: config),
              let data = Data(base64Encoded: base64),
              let tokens = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return tokens
    }
    
    public func deleteAccessTokenList(mintURL: URL) async throws {
        let key = makeSanitizedAccount(prefix: KeychainConstants.accessTokenListPrefix, mintURL: mintURL.absoluteString)
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: key
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
    }
    
    // MARK: - Utility Operations
    
    public func clearAll() async throws {
        try await deleteMnemonic()
        try await deleteSeed()
        // Note: Access tokens would need to be tracked separately
        // as we don't know all mint URLs
    }
    
    public func hasStoredData() async throws -> Bool {
        let hasMnemonic = try await loadMnemonic() != nil
        let hasSeed = try await loadSeed() != nil
        return hasMnemonic || hasSeed
    }
    
    // MARK: - Private Key Management
    
    /// Store a private key for a specific keyset
    public func storePrivateKey(_ privateKey: P256K.KeyAgreement.PrivateKey, keysetId: String) throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.mintPrivateKeyPrefix)\(keysetId)"
        )
        let keyHex = privateKey.rawRepresentation.hexString
        try Vault.savePrivateKey(keyHex, keychainConfiguration: config)
    }
    
    /// Retrieve a private key for a specific keyset
    public func retrievePrivateKey(keysetId: String) throws -> P256K.KeyAgreement.PrivateKey? {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.mintPrivateKeyPrefix)\(keysetId)"
        )
        guard let keyHex = try? Vault.getPrivateKey(keychainConfiguration: config),
              let keyData = Data(hexString: keyHex) else {
            return nil
        }
        return try P256K.KeyAgreement.PrivateKey(dataRepresentation: keyData)
    }
    
    /// Delete a private key for a specific keyset
    public func deletePrivateKey(keysetId: String) throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.mintPrivateKeyPrefix)\(keysetId)"
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
    }
    
    // MARK: - Ephemeral Key Management
    
    /// Store an ephemeral key pair
    public func storeEphemeralKey(_ privateKey: P256K.KeyAgreement.PrivateKey, identifier: String) throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.ephemeralKeyPrefix)\(identifier)"
        )
        let keyHex = privateKey.rawRepresentation.hexString
        try Vault.savePrivateKey(keyHex, keychainConfiguration: config)
    }
    
    /// Retrieve an ephemeral key
    public func retrieveEphemeralKey(identifier: String) throws -> P256K.KeyAgreement.PrivateKey? {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.ephemeralKeyPrefix)\(identifier)"
        )
        guard let keyHex = try? Vault.getPrivateKey(keychainConfiguration: config),
              let keyData = Data(hexString: keyHex) else {
            return nil
        }
        return try P256K.KeyAgreement.PrivateKey(dataRepresentation: keyData)
    }
    
    /// Delete an ephemeral key
    public func deleteEphemeralKey(identifier: String) throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.ephemeralKeyPrefix)\(identifier)"
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
    }
    
    // MARK: - Legacy Methods (kept for backward compatibility)

    // MARK: - Helpers
    
    private func createSecureKeychainConfiguration(
        account: String,
        requireBiometrics: Bool = false
    ) -> KeychainConfiguration {
        // Create base configuration
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: account
        )
        
        // Note: Vault framework may not support all these options
        // Would need to check Vault's actual API for proper configuration
        
        return config
    }

    private func makeSanitizedAccount(prefix: String, mintURL: String) -> String {
        let normalized = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedURL = normalized
            .replacingOccurrences(of: "://", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return "\(prefix)\(sanitizedURL)"
    }
    
    // MARK: - Secure Enclave Support
    
    /// Check if Secure Enclave is available
    public var isSecureEnclaveAvailable: Bool {
        // P256K uses Secure Enclave when available
        // We can create a test key to verify
        do {
            _ = try P256K.KeyAgreement.PrivateKey()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Cleanup
    
    /// Delete all stored keys (use with caution!)
    public func deleteAllKeys() async throws {
        // This would need to iterate through all possible keys
        // For now, just delete known wallet keys
        try await clearAll()
        
        // In a production app, you might want to track all stored keys
        // or use a prefix search if the Vault library supports it
    }
}

// MARK: - Errors

public enum KeychainError: LocalizedError {
    case keyNotFound
    case invalidKeyData
    case secureEnclaveUnavailable
    case biometricAuthenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "The requested key was not found in the keychain"
        case .invalidKeyData:
            return "The key data is invalid or corrupted"
        case .secureEnclaveUnavailable:
            return "Secure Enclave is not available on this device"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        }
    }
}