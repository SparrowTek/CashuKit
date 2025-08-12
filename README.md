# CashuKit

> ⚠️ **WARNING: NOT PRODUCTION READY** ⚠️
> 
> This library is under active development and is NOT yet suitable for production use.
> - Security features are still being implemented
> - API may change significantly
> - Some critical features are incomplete
> - Not audited for security vulnerabilities
> 
> **DO NOT USE WITH REAL FUNDS**

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-blue.svg)](https://developer.apple.com)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Native Apple platform client library for the Cashu ecash protocol. CashuKit provides deep integration with iOS, macOS, and other Apple platforms, leveraging system frameworks for security, performance, and user experience.

## Overview

CashuKit is the Apple-native layer built on top of [CoreCashu](../CoreCashu), providing:
- **Deep Platform Integration**: Keychain, Face ID, iCloud sync, and more
- **Native UI Components**: Ready-to-use SwiftUI views for wallet functionality
- **Background Processing**: Continue wallet operations when your app is suspended
- **Network Resilience**: Intelligent offline handling with automatic retry
- **Privacy-First**: Native logging with sensitive data redaction

## Architecture

```
┌─────────────────────────────────────────┐
│           Your iOS/macOS App            │
├─────────────────────────────────────────┤
│              CashuKit                   │  ← You are here
│  (Apple Platform Integration Layer)     │
├─────────────────────────────────────────┤
│              CoreCashu                  │
│    (Platform-Agnostic Protocol)         │
└─────────────────────────────────────────┘
```

## Key Features

### 🍎 Apple Platform Integration
- **Keychain & Secure Enclave**: Hardware-backed key storage with biometric protection
- **Face ID / Touch ID / Optic ID**: Seamless biometric authentication
- **iCloud Keychain Sync**: Optional cross-device wallet synchronization
- **Background Execution**: Continue operations when app is backgrounded
- **Network Monitoring**: Intelligent offline queueing and retry logic
- **Structured Logging**: Privacy-preserving os.log integration
- **SwiftUI Components**: Pre-built, customizable wallet UI

### ⚡ Protocol Features (via CoreCashu)
- Complete implementation of Cashu NIPs (NUT-00 through NUT-22)
- Lightning Network integration (mint & melt)
- Deterministic secrets with BIP39/BIP32
- Advanced spending conditions (P2PK, HTLCs)
- Multi-path payments
- WebSocket subscriptions
- Token state management

## Installation

### Requirements
- iOS 17.0+ / macOS 15.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Xcode 16.0+
- Swift 6.0+

### Swift Package Manager

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/CashuKit", from: "0.1.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
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
try await wallet.connectToMint(url: "https://testnut.cashu.space")

// Check balance
let balance = await wallet.balance
print("Balance: \(balance) sats")

// Send ecash
let token = try await wallet.send(amount: 100, memo: "Coffee payment")
print("Token: \(token)")

// Receive ecash
try await wallet.receive(token: receivedTokenString)
```

### SwiftUI Integration

```swift
import SwiftUI
import CashuKit

@main
struct MyWalletApp: App {
    @StateObject private var wallet = AppleCashuWallet()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wallet)
                .networkStatus(monitor: networkMonitor)
                .requireBiometricAuth()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var wallet: AppleCashuWallet
    
    var body: some View {
        NavigationStack {
            VStack {
                // Pre-built UI components
                CashuBalanceView(wallet: wallet)
                CashuSendReceiveView(wallet: wallet)
                CashuTransactionListView(wallet: wallet)
                MintSelectionView(wallet: wallet)
            }
            .navigationTitle("My Cashu Wallet")
        }
    }
}
```

### Secure Storage Configuration

```swift
// Default configuration (recommended)
let wallet = await AppleCashuWallet()

// Custom security configuration
let secureStore = KeychainSecureStore(
    accessGroup: "group.com.yourapp.cashu",
    securityConfiguration: .init(
        useBiometrics: true,
        useSecureEnclave: true,
        accessibleWhenUnlocked: false,
        synchronizable: true  // Enable iCloud sync
    )
)

let customWallet = await AppleCashuWallet(secureStore: secureStore)
```

### Background Task Management

```swift
// In your AppDelegate or App initialization
let networkMonitor = NetworkMonitor()
let backgroundTaskManager = BackgroundTaskManager(networkMonitor: networkMonitor)

// Register background tasks
backgroundTaskManager.registerBackgroundTasks()
backgroundTaskManager.setupLifecycleObservers()

// Schedule periodic balance refresh
try await backgroundTaskManager.scheduleBackgroundTask(.balanceRefresh)

// Queue operations for background execution
await backgroundTaskManager.addPendingOperation(
    type: "token_sync",
    data: syncData
)
```

### Network Monitoring

```swift
let networkMonitor = NetworkMonitor()

// Start monitoring
await networkMonitor.startMonitoring()

// React to network changes
for await status in networkMonitor.$currentStatus.values {
    if status.isConnected {
        // Process queued operations
        await networkMonitor.processQueuedOperations()
    }
}

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
let mnemonic = try Mnemonic.generate()
print("Save these words: \(mnemonic.words.joined(separator: " "))")

// Create wallet from mnemonic
let wallet = try await AppleCashuWallet(mnemonic: mnemonic)

// Restore wallet balance from mint
let restoredBalance = try await wallet.restoreFromMint()
print("Restored \(restoredBalance) sats")
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
        // Store sensitive data with biometric protection
        try await bioManager.storeWithBiometricProtection(
            data: seedData,
            account: "wallet_seed",
            service: "com.yourapp.cashu"
        )
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

// Set custom metrics sink for production
logger.setMetricsSink(MyTelemetryAdapter())

// Sensitive data is automatically redacted
logger.info("Sending \(amount) sats", metadata: [
    "mint": mintURL,
    "token": token  // Automatically redacted
])
```

### WebSocket Subscriptions

```swift
// Create WebSocket client
let wsClient = AppleWebSocketClient(
    url: "wss://mint.example.com/v1/ws",
    logger: logger
)

// Subscribe to mint updates
await wsClient.connect()
await wsClient.subscribe(to: .proofStateUpdates) { update in
    // Handle real-time updates
}
```

## UI Components

CashuKit provides ready-to-use SwiftUI components:

- **CashuBalanceView**: Displays wallet balance with automatic updates
- **CashuSendReceiveView**: Token sending and receiving interface
- **CashuTransactionListView**: Transaction history with search and filters
- **MintSelectionView**: Mint management and selection
- **NetworkStatusModifier**: Offline/online status banner

All components are customizable through view modifiers and environment values.

## Security Considerations

⚠️ **This library has NOT been security audited and should NOT be used in production.**

### Current Security Implementation
- Hardware-backed key storage via Secure Enclave
- Biometric authentication for sensitive operations
- Automatic sensitive data redaction in logs
- Secure random generation via system APIs
- Constant-time cryptographic operations
- Actor-based concurrency for thread safety

### Missing Security Features
- Third-party security audit
- Rate limiting for mint requests
- Circuit breakers for network failures
- Certificate pinning for mint connections
- Anti-tampering measures

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
5. **UI Components**: Additional SwiftUI views

Please open an issue before starting major work.

## Dependencies

- [CoreCashu](../CoreCashu) - Platform-agnostic Cashu protocol
- [swift-secp256k1](https://github.com/21-DOT-DEV/swift-secp256k1) - Elliptic curve cryptography
- [BigInt](https://github.com/attaswift/BigInt) - Arbitrary precision arithmetic
- [BitcoinDevKit](https://github.com/bitcoindevkit/bdk-swift) - Bitcoin functionality
- [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) - Additional cryptography

## License

CashuKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Cashu Protocol](https://docs.cashu.space) - The underlying ecash protocol
- [cashubtc/nuts](https://github.com/cashubtc/nuts) - Protocol specifications
- The Cashu community for protocol development and support

---

**Remember**: This is experimental software. Use at your own risk and only with testnet funds.