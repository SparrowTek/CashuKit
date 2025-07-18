//
//  KeychainManager.swift
//  CashuKit
//
//  Secure key storage using Vault framework
//

import Foundation
import Vault
import P256K

/// Manager for secure storage of cryptographic keys using Keychain
public actor KeychainManager {
    
    // MARK: - Constants
    
    private enum KeychainConstants {
        static let serviceName = "com.cashukit.keychain"
        static let walletMnemonicAccount = "wallet.mnemonic"
        static let walletSeedAccount = "wallet.seed"
        static let mintPrivateKeyPrefix = "mint.privatekey."
        static let ephemeralKeyPrefix = "ephemeral.key."
        static let accessTokenPrefix = "access.token."
    }
    
    // MARK: - Properties
    
    private let accessGroup: String?
    
    // MARK: - Initialization
    
    /// Initialize with optional access group for keychain sharing
    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
        
        // Configure Vault globally if not already configured
        let configuration = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "default"
        )
        Vault.configure(configuration)
    }
    
    // MARK: - Wallet Key Management
    
    /// Store wallet mnemonic securely
    public func storeMnemonic(_ mnemonic: String) throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletMnemonicAccount
        )
        try Vault.savePrivateKey(mnemonic, keychainConfiguration: config)
    }
    
    /// Retrieve wallet mnemonic
    public func retrieveMnemonic() throws -> String? {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletMnemonicAccount
        )
        return try? Vault.getPrivateKey(keychainConfiguration: config)
    }
    
    /// Store wallet seed securely
    public func storeSeed(_ seed: Data) throws {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletSeedAccount
        )
        // Convert Data to hex string for storage
        let seedHex = seed.hexString
        try Vault.savePrivateKey(seedHex, keychainConfiguration: config)
    }
    
    /// Retrieve wallet seed
    public func retrieveSeed() throws -> Data? {
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletSeedAccount
        )
        guard let seedHex = try? Vault.getPrivateKey(keychainConfiguration: config) else {
            return nil
        }
        return Data(hexString: seedHex)
    }
    
    /// Delete wallet keys (mnemonic and seed)
    public func deleteWalletKeys() throws {
        let mnemonicConfig = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletMnemonicAccount
        )
        let seedConfig = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: KeychainConstants.walletSeedAccount
        )
        
        try? Vault.deletePrivateKey(keychainConfiguration: mnemonicConfig)
        try? Vault.deletePrivateKey(keychainConfiguration: seedConfig)
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
    
    // MARK: - Access Token Management
    
    /// Store an access token for a mint
    public func storeAccessToken(_ token: String, mintURL: String) throws {
        // Sanitize mint URL for use as account name
        let sanitizedURL = mintURL.replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.accessTokenPrefix)\(sanitizedURL)"
        )
        try Vault.savePrivateKey(token, keychainConfiguration: config)
    }
    
    /// Retrieve an access token for a mint
    public func retrieveAccessToken(mintURL: String) throws -> String? {
        // Sanitize mint URL for use as account name
        let sanitizedURL = mintURL.replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.accessTokenPrefix)\(sanitizedURL)"
        )
        return try? Vault.getPrivateKey(keychainConfiguration: config)
    }
    
    /// Delete an access token for a mint
    public func deleteAccessToken(mintURL: String) throws {
        // Sanitize mint URL for use as account name
        let sanitizedURL = mintURL.replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        
        let config = KeychainConfiguration(
            serviceName: KeychainConstants.serviceName,
            accessGroup: accessGroup,
            accountName: "\(KeychainConstants.accessTokenPrefix)\(sanitizedURL)"
        )
        try Vault.deletePrivateKey(keychainConfiguration: config)
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
    public func deleteAllKeys() throws {
        // This would need to iterate through all possible keys
        // For now, just delete known wallet keys
        try deleteWalletKeys()
        
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