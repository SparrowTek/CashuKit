# CashuKit

> **BETA STATUS** - Security Audit Preparation Complete
> 
> CashuKit has completed security hardening alongside CoreCashu:
> - 69 tests passing with Keychain-based secure storage
> - Biometric authentication (Face ID / Touch ID / Optic ID)
> - Network monitoring with secure offline queueing
> - Privacy-preserving structured logging
> 
> **Pending external security audit before production use with significant funds.**
> Built on [CoreCashu](../CoreCashu) - see its security documentation for details.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-blue.svg)](https://developer.apple.com)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Native Apple platform SDK for the Cashu ecash protocol. CashuKit provides deep integration with iOS, macOS, and other Apple platforms, leveraging system frameworks for security, performance, and reliability.

## Overview

CashuKit is a **headless SDK** built on top of [CoreCashu](https://github.com/SparrowTek/CoreCashu). It provides Apple-platform-specific implementations but **does not include any UI components**. Apps are expected to build their own user interfaces using the CashuKit APIs.

**What CashuKit provides:**
- Keychain-based secure storage
- Face ID / Touch ID / Optic ID authentication
- iCloud Keychain sync support
- Background task processing
- Network monitoring with offline queueing
- Privacy-preserving structured logging

**What CashuKit does NOT provide:**
- SwiftUI views or UI components
- Pre-built wallet screens
- Transaction list views

For UI implementation, refer to the example app or build your own using the `AppleCashuWallet` class.

## Architecture

```
┌─────────────────────────────────────────┐
│           Your iOS/macOS App            │
│         (Your UI goes here)             │
├─────────────────────────────────────────┤
│              CashuKit                   │  ← You are here
│  (Apple Platform Integration - No UI)  │
├─────────────────────────────────────────┤
│              CoreCashu                  │
│    (Platform-Agnostic Protocol)         │
└─────────────────────────────────────────┘
```

## Key Features

### Apple Platform Integration
- **Keychain & Secure Enclave**: Hardware-backed key storage with biometric protection
- **Face ID / Touch ID / Optic ID**: Seamless biometric authentication
- **iCloud Keychain Sync**: Optional cross-device wallet synchronization
- **Background Execution**: Continue operations when app is backgrounded
- **Network Monitoring**: Intelligent offline queueing and retry logic
- **Structured Logging**: Privacy-preserving os.log integration

### Protocol Features (via CoreCashu)
- Complete implementation of Cashu NIPs (NUT-00 through NUT-22)
- Lightning Network integration (mint & melt)
- Deterministic secrets with BIP39/BIP32
- Advanced spending conditions (P2PK, HTLCs)
- Multi-path payments
- WebSocket subscriptions
- Token state management

## Installation

### Requirements
- iOS 17.0+ / macOS 15.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 2.0+
- Xcode 16.0+
- Swift 6.0+

### Swift Package Manager

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CashuKit", from: "0.1.0")
]
```

Or in Xcode:
1. File -> Add Package Dependencies
2. Enter the repository URL
3. Select CashuKit product

### Configuration

Add to your app's `Info.plist`:
```xml
<!-- Required for biometric authentication -->
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your Cashu wallet</string>

<!-- Optional: For background tasks -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>

<!-- Optional: Register background task identifiers -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.cashukit.balance.refresh</string>
    <string>com.cashukit.proof.validation</string>
    <string>com.cashukit.token.sync</string>
    <string>com.cashukit.mint.health</string>
</array>
```

## Quick Start

### Basic Wallet Setup

```swift
import CashuKit
import CoreCashu

// Create wallet with Apple platform defaults
let wallet = await AppleCashuWallet()

// Connect to a mint
try await wallet.connect(to: URL(string: "https://testnut.cashu.space")!)

// Check balance
let balance = await wallet.balance
print("Balance: \(balance) sats")

// Send ecash
let token = try await wallet.send(amount: 100, memo: "Coffee payment")
print("Token: \(try wallet.encodeToken(token))")

// Receive ecash
let proofs = try await wallet.receive(token: receivedTokenString)
print("Received \(proofs.count) proofs")
```

### SwiftUI Integration

Since CashuKit is a headless SDK, you build your own UI:

```swift
import SwiftUI
import CashuKit

@main
struct MyWalletApp: App {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wallet)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var wallet: AppleCashuWallet
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Build your own balance display
                Text("\(wallet.balance) sats")
                    .font(.largeTitle)
                
                // Build your own send/receive UI
                Button("Send 100 sats") {
                    Task {
                        let token = try await wallet.send(amount: 100)
                        // Handle token...
                    }
                }
                
                // Build your own transaction list
                // ...
            }
            .navigationTitle("My Wallet")
        }
    }
}
```

### Secure Storage Configuration

```swift
// Default configuration (recommended)
let wallet = await AppleCashuWallet()

// Custom configuration
let config = AppleCashuWallet.Configuration(
    keychainAccessGroup: "group.com.yourapp.cashu",
    enableBiometrics: true,
    enableiCloudSync: true
)
let customWallet = await AppleCashuWallet(configuration: config)
```

### Background Task Management

```swift
// In your AppDelegate or App initialization
let networkMonitor = await NetworkMonitor()
let backgroundTaskManager = BackgroundTaskManager(networkMonitor: networkMonitor)

// Register background tasks
await backgroundTaskManager.registerBackgroundTasks()

// Queue operations for background execution
await backgroundTaskManager.addPendingOperation(
    type: "token_sync",
    data: syncData
)
```

### Network Monitoring

```swift
let networkMonitor = await NetworkMonitor()

// Start monitoring
await networkMonitor.startMonitoring()

// Check status
let isConnected = await networkMonitor.isConnected

// Queue operations when offline
await networkMonitor.queueOperation(
    type: .sendToken,
    data: tokenData,
    priority: .high
)
```

## Advanced Usage

### Wallet Restoration

```swift
// Generate new mnemonic
let mnemonic = try await wallet.generateMnemonic()
print("Save these words: \(mnemonic)")

// Restore wallet from mnemonic
try await wallet.restore(mnemonic: savedMnemonic)
```

### Biometric Authentication

```swift
let bioManager = BiometricAuthManager.shared

// Check availability
await bioManager.checkBiometricAvailability()

if await bioManager.isAvailable {
    // Authenticate user
    let authenticated = try await bioManager.authenticateUser(
        reason: "Access your Cashu wallet"
    )
    
    if authenticated {
        // Proceed with sensitive operation
    }
}
```

### Custom Logging

```swift
// Configure logging
let logger = OSLogLogger(
    category: "CashuWallet",
    minimumLevel: .debug
)

// Sensitive data is automatically redacted
logger.info("Sending transaction", metadata: [
    "mint": mintURL,
    "amount": amount
])
```

### WebSocket Subscriptions

```swift
// Create WebSocket client
let wsClient = AppleWebSocketClient(
    configuration: WebSocketConfiguration(
        connectionTimeout: 10,
        pingInterval: 30
    )
)

// Connect and subscribe
try await wsClient.connect(to: URL(string: "wss://mint.example.com/v1/ws")!)
```

`connect(to:)` validates the connection with a ping probe before `isConnected` is set to `true`.
`send`, `receive`, and `ping` are bounded by `connectionTimeout` and throw `WebSocketError.timeout` on slow or unresponsive links.

## Security

CashuKit provides Apple platform security integrations on top of CoreCashu's protocol security.

### Platform Security Features
- **Keychain Storage**: Hardware-backed key storage with Secure Enclave support
- **Biometric Authentication**: Face ID, Touch ID, Optic ID for sensitive operations
- **iCloud Keychain Sync**: Optional cross-device synchronization (encrypted)
- **Privacy-Preserving Logging**: Automatic sensitive data redaction in os.log
- **Secure Operation Queue**: Offline operations stored in Keychain (not UserDefaults)

### Inherited from CoreCashu
- Rate limiting and circuit breakers
- Constant-time cryptographic operations
- Memory zeroization for sensitive data
- BIP39/BIP32 deterministic key derivation

### Audit Status
CashuKit is **ready for external security audit** alongside CoreCashu. See [CoreCashu Security Documentation](../CoreCashu/Docs/) for the complete threat model.

**Production use with significant funds should await completion of external audit.**

## Testing

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter CashuKitTests

# Run with coverage
swift test --enable-code-coverage
```

## Contributing

We welcome contributions! Areas that need work:

1. **Security**: Hardening and audit preparation
2. **Testing**: Increase test coverage
3. **Documentation**: API documentation and guides
4. **Performance**: Optimization for large wallets

Please open an issue before starting major work.

## Dependencies

- [CoreCashu](../CoreCashu) - Platform-agnostic Cashu protocol
- [swift-secp256k1](https://github.com/21-DOT-DEV/swift-secp256k1) - Elliptic curve cryptography
- [BigInt](https://github.com/attaswift/BigInt) - Arbitrary precision arithmetic
- [BitcoinDevKit](https://github.com/bitcoindevkit/bdk-swift) - Bitcoin functionality
- [Vault](https://github.com/SparrowTek/Vault) - Keychain wrapper

## License

CashuKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Cashu Protocol](https://docs.cashu.space) - The underlying ecash protocol
- [cashubtc/nuts](https://github.com/cashubtc/nuts) - Protocol specifications
- The Cashu community for protocol development and support

---

**Status**: Beta - Security audit preparation complete. External audit pending before production use with significant funds.
