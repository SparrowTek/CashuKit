/// # Basic Wallet Setup
///
/// This example demonstrates how to create and initialize a CashuKit wallet
/// on Apple platforms.

import CashuKit
import Foundation

// MARK: - Basic Wallet Setup

/// Create a wallet with default Apple platform settings
func createBasicWallet() async throws -> AppleCashuWallet {
    // Create wallet with defaults:
    // - Keychain storage
    // - Biometric protection available
    // - Network monitoring enabled
    let wallet = await AppleCashuWallet()
    
    // Connect to a mint
    let mintURL = URL(string: "https://testnut.cashu.space")!
    try await wallet.connect(to: mintURL)
    
    return wallet
}

// MARK: - Custom Configuration

/// Create a wallet with custom security settings
func createCustomWallet() async throws -> AppleCashuWallet {
    let config = AppleCashuWallet.Configuration(
        // Share wallet with app extensions
        keychainAccessGroup: "group.com.yourapp.cashu",
        
        // Require biometrics for sensitive operations
        enableBiometrics: true,
        
        // Keep wallet data local (no iCloud sync)
        enableiCloudSync: false
    )
    
    let wallet = await AppleCashuWallet(configuration: config)
    
    let mintURL = URL(string: "https://mint.example.com")!
    try await wallet.connect(to: mintURL)
    
    return wallet
}

// MARK: - SwiftUI Integration

/*
import SwiftUI

@main
struct MyWalletApp: App {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wallet)
                .task {
                    // Connect on app launch
                    try? await wallet.connect(
                        to: URL(string: "https://testnut.cashu.space")!
                    )
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var wallet: AppleCashuWallet
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Balance display
                Text("\(wallet.balance) sats")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                // Loading indicator
                if wallet.isLoading {
                    ProgressView()
                }
                
                // Connection status
                if !wallet.isConnected {
                    Label("Offline", systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 40) {
                    Button {
                        // Navigate to receive
                    } label: {
                        Label("Receive", systemImage: "arrow.down.circle")
                    }
                    
                    Button {
                        // Navigate to send
                    } label: {
                        Label("Send", systemImage: "arrow.up.circle")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Wallet")
            .refreshable {
                await wallet.refreshBalance()
            }
        }
    }
}
*/

// MARK: - Wallet with Biometric Protection

/// Set up a wallet that requires biometric authentication
func setupBiometricWallet() async throws -> AppleCashuWallet {
    // Check biometric availability
    let bioManager = BiometricAuthManager.shared
    await bioManager.checkBiometricAvailability()
    
    guard await bioManager.isAvailable else {
        print("Biometrics not available on this device")
        // Fall back to passcode or other authentication
        return await AppleCashuWallet()
    }
    
    // Authenticate before creating wallet
    try await bioManager.authenticateUser(
        reason: "Authenticate to set up your wallet"
    )
    
    // Create wallet with biometrics enabled
    let config = AppleCashuWallet.Configuration(
        enableBiometrics: true
    )
    
    return await AppleCashuWallet(configuration: config)
}

// MARK: - Multi-Platform Considerations

/// Platform-specific wallet setup
func createPlatformOptimizedWallet() async throws -> AppleCashuWallet {
    var config = AppleCashuWallet.Configuration()
    
    #if os(iOS)
    // iOS: Enable all features
    config.enableBiometrics = true
    #elseif os(macOS)
    // macOS: Touch ID if available
    config.enableBiometrics = true
    #elseif os(watchOS)
    // watchOS: Simplified setup, device is already authenticated
    config.enableBiometrics = false
    #elseif os(visionOS)
    // visionOS: Optic ID
    config.enableBiometrics = true
    #endif
    
    return await AppleCashuWallet(configuration: config)
}

// MARK: - App Group Sharing

/// Create a wallet that can be shared between app and extensions
func createSharedWallet() async throws -> AppleCashuWallet {
    // Both your main app and extensions must have the same
    // keychain access group in their entitlements:
    //
    // Entitlements:
    //   keychain-access-groups: ["group.com.yourapp.shared"]
    //   app-groups: ["group.com.yourapp.shared"]
    
    let config = AppleCashuWallet.Configuration(
        keychainAccessGroup: "group.com.yourapp.shared"
    )
    
    return await AppleCashuWallet(configuration: config)
}
