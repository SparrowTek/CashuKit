//
//  BiometricAuthManager.swift
//  CashuKit
//
//  Biometric authentication support for secure wallet access
//

import Foundation
import LocalAuthentication
import CoreCashu

/// Manages biometric authentication for wallet operations
public actor BiometricAuthManager {
    
    // MARK: - Types
    
    public enum BiometricType: Sendable {
        case none
        case touchID
        case faceID
        case opticID // Vision Pro
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }
    }
    
    public enum AuthenticationError: LocalizedError {
        case biometryNotAvailable
        case biometryNotEnrolled
        case userCancelled
        case userFallback
        case systemCancelled
        case passcodeNotSet
        case failed(String)
        case lockout
        case invalidContext
        
        public var errorDescription: String? {
            switch self {
            case .biometryNotAvailable:
                return "Biometric authentication is not available on this device"
            case .biometryNotEnrolled:
                return "No biometric data is enrolled. Please set up biometric authentication in Settings"
            case .userCancelled:
                return "Authentication was cancelled by the user"
            case .userFallback:
                return "User chose to use fallback authentication method"
            case .systemCancelled:
                return "Authentication was cancelled by the system"
            case .passcodeNotSet:
                return "Device passcode is not set"
            case .failed(let reason):
                return "Authentication failed: \(reason)"
            case .lockout:
                return "Biometric authentication is locked due to too many failed attempts"
            case .invalidContext:
                return "Invalid authentication context"
            }
        }
    }
    
    public struct AuthenticationPolicy: OptionSet, Sendable {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        // Require biometric authentication (no passcode fallback)
        public static let biometryOnly = AuthenticationPolicy(rawValue: 1 << 0)
        
        // Allow passcode as fallback
        public static let deviceOwnerAuthentication = AuthenticationPolicy(rawValue: 1 << 1)
        
        // Require authentication for sensitive operations only
        public static let sensitiveOperationsOnly = AuthenticationPolicy(rawValue: 1 << 2)
        
        // Invalidate on biometry change (re-enrollment)
        public static let invalidateOnBiometryChange = AuthenticationPolicy(rawValue: 1 << 3)
        
        // Default policy
        public static let `default`: AuthenticationPolicy = [.deviceOwnerAuthentication, .sensitiveOperationsOnly]
    }
    
    // MARK: - Properties
    
    public static let shared = BiometricAuthManager()
    
    private let context = LAContext()
    private var policy: AuthenticationPolicy = .default
    private let logger: OSLogLogger
    
    public private(set) var biometricType: BiometricType = .none
    public private(set) var isAvailable: Bool = false
    public private(set) var isEnrolled: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        self.logger = OSLogLogger(category: "BiometricAuth", minimumLevel: .info)
        Task {
            await checkBiometricAvailability()
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure authentication policy
    public func configure(policy: AuthenticationPolicy) {
        self.policy = policy
        logger.info("Biometric authentication policy updated")
    }
    
    /// Check if biometric authentication is available and configured
    public func checkBiometricAvailability() {
        var error: NSError?
        
        // Check if biometry is available
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if canEvaluate {
            isAvailable = true
            isEnrolled = true
            
            // Determine biometric type
            switch context.biometryType {
            case .none:
                biometricType = .none
            case .touchID:
                biometricType = .touchID
            case .faceID:
                biometricType = .faceID
            case .opticID:
                biometricType = .opticID
            @unknown default:
                biometricType = .none
            }
            
            logger.info("Biometric authentication available: \(biometricType.displayName)")
        } else {
            isAvailable = false
            biometricType = .none
            
            if let error = error {
                switch error.code {
                case LAError.biometryNotEnrolled.rawValue:
                    isEnrolled = false
                    logger.warning("Biometry not enrolled")
                case LAError.biometryNotAvailable.rawValue:
                    logger.warning("Biometry not available on device")
                default:
                    logger.error("Biometry evaluation error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Authenticate user with biometrics
    /// - Parameters:
    ///   - reason: The reason for authentication shown to user
    ///   - fallbackTitle: Custom title for fallback button (nil uses system default)
    /// - Returns: Success or failure
    public func authenticate(
        reason: String,
        fallbackTitle: String? = nil
    ) async throws {
        // Check availability first
        guard isAvailable else {
            throw AuthenticationError.biometryNotAvailable
        }
        
        guard isEnrolled else {
            throw AuthenticationError.biometryNotEnrolled
        }
        
        // Create new context for each authentication
        let authContext = LAContext()
        
        // Configure context
        authContext.localizedCancelTitle = "Cancel"
        if let fallbackTitle = fallbackTitle {
            authContext.localizedFallbackTitle = fallbackTitle
        }
        
        // Set timeout (default is 30 seconds)
        authContext.touchIDAuthenticationAllowableReuseDuration = 10
        
        // Determine policy based on configuration
        let evaluationPolicy: LAPolicy = policy.contains(.biometryOnly) 
            ? .deviceOwnerAuthenticationWithBiometrics 
            : .deviceOwnerAuthentication
        
        do {
            // Perform authentication
            let success = try await authContext.evaluatePolicy(
                evaluationPolicy,
                localizedReason: reason
            )
            
            if success {
                logger.info("Biometric authentication successful")
            } else {
                logger.error("Biometric authentication failed")
                throw AuthenticationError.failed("Unknown error")
            }
        } catch let error as LAError {
            logger.error("LAError during authentication: \(error.localizedDescription)")
            throw mapLAError(error)
        } catch {
            logger.error("Unknown error during authentication: \(error.localizedDescription)")
            throw AuthenticationError.failed(error.localizedDescription)
        }
    }
    
    /// Authenticate for sensitive operation
    /// - Parameter operation: Description of the operation
    public func authenticateForSensitiveOperation(_ operation: String) async throws {
        guard policy.contains(.sensitiveOperationsOnly) else {
            // If not configured for sensitive ops only, always authenticate
            try await authenticate(reason: operation)
            return
        }
        
        // Define which operations are considered sensitive
        let sensitiveKeywords = ["send", "export", "delete", "restore", "mnemonic", "seed", "private"]
        let isSensitive = sensitiveKeywords.contains { operation.lowercased().contains($0) }
        
        if isSensitive {
            try await authenticate(reason: operation)
        }
    }
    
    /// Create a secured LAContext for Keychain operations
    public func createSecuredContext() throws -> LAContext {
        let securedContext = LAContext()
        
        // Evaluate policy to "arm" the context
        var error: NSError?
        guard securedContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let nsError = error {
                // Safely cast to LAError if possible, otherwise use the error description
                if let laError = nsError as? LAError {
                    throw mapLAError(laError)
                } else {
                    throw AuthenticationError.failed(nsError.localizedDescription)
                }
            }
            throw AuthenticationError.biometryNotAvailable
        }
        
        return securedContext
    }
    
    /// Invalidate the context (should be called when app goes to background)
    public func invalidate() {
        context.invalidate()
        logger.debug("Biometric context invalidated")
    }
    
    // MARK: - Private Methods
    
    private func mapLAError(_ error: LAError) -> AuthenticationError {
        switch error.code {
        case .authenticationFailed:
            return .failed("Authentication failed")
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .lockout
        case .appCancel:
            return .systemCancelled
        case .invalidContext:
            return .invalidContext
        case .notInteractive:
            return .failed("Authentication not interactive")
        default:
            return .failed(error.localizedDescription)
        }
    }
}

// MARK: - Keychain Integration Extension

public extension BiometricAuthManager {
    
    /// Create keychain access control with biometric protection
    /// - Returns: SecAccessControl configured for biometric authentication
    func createBiometricAccessControl() throws -> SecAccessControl {
        var accessControlError: Unmanaged<CFError>?
        
        // Determine access control flags based on policy
        var flags: SecAccessControlCreateFlags = []
        
        if policy.contains(.biometryOnly) {
            // Require biometry only (no passcode fallback)
            #if os(iOS)
            flags = .biometryCurrentSet
            #else
            flags = .biometryAny
            #endif
        } else {
            // Allow biometry or passcode
            flags = .userPresence
        }
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            &accessControlError
        ) else {
            if let error = accessControlError?.takeRetainedValue() {
                throw AuthenticationError.failed("Failed to create access control: \(error)")
            }
            throw AuthenticationError.failed("Failed to create access control")
        }
        
        return accessControl
    }
    
    /// Store data in keychain with biometric protection
    func storeWithBiometricProtection(
        data: Data,
        account: String,
        service: String
    ) async throws {
        // Authenticate first
        try await authenticate(reason: "Authenticate to securely store data")
        
        // Create access control
        let accessControl = try createBiometricAccessControl()
        
        // Prepare keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw AuthenticationError.failed("Failed to store data: \(status)")
        }
        
        logger.info("Data stored with biometric protection")
    }
    
    /// Retrieve data from keychain with biometric authentication
    func retrieveWithBiometricAuth(
        account: String,
        service: String,
        reason: String
    ) async throws -> Data {
        // Create context for this operation
        let authContext = LAContext()
        authContext.localizedReason = reason
        
        // Prepare keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: authContext
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw AuthenticationError.failed("Failed to retrieve data: \(status)")
        }
        
        logger.info("Data retrieved with biometric authentication")
        return data
    }
}

// MARK: - SwiftUI View Modifier

#if canImport(SwiftUI)
import SwiftUI

public struct BiometricAuthModifier: ViewModifier {
    @State private var isAuthenticated = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let requirement: BiometricAuthManager.AuthenticationPolicy
    let reason: String
    
    public func body(content: Content) -> some View {
        Group {
            if isAuthenticated {
                content
            } else {
                BiometricAuthView(
                    isAuthenticated: $isAuthenticated,
                    showError: $showError,
                    errorMessage: $errorMessage,
                    reason: reason
                )
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct BiometricAuthView: View {
    @Binding var isAuthenticated: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    let reason: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")  // Default to Face ID icon
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Authentication Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(reason)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: authenticate) {
                Label("Authenticate", systemImage: "lock.shield")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        Task {
            do {
                try await BiometricAuthManager.shared.authenticate(reason: reason)
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

public extension View {
    /// Require biometric authentication to access this view
    func requireBiometricAuth(
        policy: BiometricAuthManager.AuthenticationPolicy = .default,
        reason: String = "Authenticate to access your wallet"
    ) -> some View {
        modifier(BiometricAuthModifier(requirement: policy, reason: reason))
    }
}
#endif