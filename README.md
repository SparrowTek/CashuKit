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

Apple-specific Swift package for the Cashu ecash protocol. CashuKit provides native iOS/macOS implementations with deep platform integration, built on top of [CoreCashu](../CoreCashu) for protocol logic.

## Architecture

CashuKit is designed as an Apple-specific layer on top of CoreCashu:

- **CoreCashu**: Platform-agnostic Cashu protocol implementation
- **CashuKit**: Apple platform integrations (Keychain, biometrics, SwiftUI, etc.)

## Current Status

### ✅ Apple Platform Features
- **Keychain Integration**: Secure storage with `KeychainSecureStore`
- **Biometric Authentication**: Face ID, Touch ID, and Optic ID support
- **SwiftUI Components**: Ready-to-use wallet UI components
- **Network Monitoring**: Intelligent offline/online handling with `NetworkMonitor`
- **Background Tasks**: Wallet operations continue when app is suspended
- **Structured Logging**: Native `os.log` integration with privacy controls
- **WebSocket Support**: Native `URLSessionWebSocketTask` implementation

### ✅ Protocol Support (via CoreCashu)
- **Core Protocol**: NUT-00 through NUT-24 implementations
- **Wallet Operations**: Mint, melt, swap, send, receive
- **Token Management**: V3/V4 token serialization, CBOR support
- **Cryptography**: BDHKE, deterministic secrets, P2PK, HTLCs
- **State Management**: Actor-based concurrency, thread safety

## Features

### Apple Platform Integration
- 🔐 **Keychain & Secure Enclave**: Hardware-backed key storage
- 👤 **Biometric Authentication**: Face ID, Touch ID, Optic ID support
- 📱 **SwiftUI Components**: Pre-built wallet UI components
- 🌐 **Network Resilience**: Automatic offline queueing and retry
- ⚡ **Background Execution**: Continue operations when app is suspended
- 📊 **Structured Logging**: Privacy-preserving os.log integration
- 🔄 **iCloud Keychain Sync**: Optional wallet sync across devices

### Core Protocol Features (from CoreCashu)
- ✅ **Complete NUT Support**: NUT-00 through NUT-24
- ✅ **Thread-Safe**: Actor-based concurrency model
- ✅ **Type-Safe**: Leverages Swift 6's type system
- ✅ **Deterministic Secrets**: BIP39/BIP32 wallet recovery
- ✅ **Advanced Conditions**: P2PK and HTLC support

## Supported Cashu NIPs (NUTs)

### Core Protocol
- **NUT-00**: Notation, Terminology and Types
- **NUT-01**: Mint public key exchange
- **NUT-02**: Keysets and keyset IDs
- **NUT-03**: Swap tokens (exchange proofs)
- **NUT-04**: Mint tokens
- **NUT-05**: Melting tokens
- **NUT-06**: Mint information

### Token Formats
- **NUT-00**: V3 Token Format (JSON-based)
- **NUT-00**: V4 Token Format (CBOR-based)

### Advanced Features
- **NUT-07**: Token state check
- **NUT-08**: Lightning fee return
- **NUT-09**: Wallet restore from seed
- **NUT-10**: Spending conditions (P2PK)
- **NUT-11**: Pay-to-Public-Key (P2PK)
- **NUT-12**: Offline ecash signature validation (DLEQ)
- **NUT-13**: Deterministic secrets (BIP39/BIP32)
- **NUT-14**: Hash Time Locked Contracts (HTLCs)
- **NUT-15**: Multi-path payments (MPP)
- **NUT-16**: Animated QR codes
- **NUT-17**: WebSocket subscriptions
- **NUT-19**: Mint Management
- **NUT-20**: Bitcoin On-Chain Support
- **NUT-22**: Non-custodial wallet authentication

## Installation

### Swift Package Manager

Add CashuKit to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../CashuKit"),  // For local development
    .package(path: "../CoreCashu")   // Required dependency
]
```

### Xcode Integration

1. File → Add Package Dependencies
2. Add local packages: CashuKit and CoreCashu
3. Select products for your target

### Required Configuration

Add to your app's Info.plist:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your Cashu wallet</string>
```

## Quick Start

### Basic Usage

```swift
import CashuKit
import CoreCashu

// Create wallet with Apple platform defaults
let wallet = AppleCashuWallet()

// Connect to mint
try await wallet.connectToMint(url: "https://testnut.cashu.space")

// Check balance
print("Balance: \(wallet.balance) sats")

// Send tokens
let token = try await wallet.send(amount: 100, memo: "Coffee")

// Receive tokens
try await wallet.receive(token: tokenString)
```

### SwiftUI Integration

```swift
import SwiftUI
import CashuKit

struct WalletView: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        NavigationView {
            VStack {
                CashuBalanceView(wallet: wallet)
                CashuSendReceiveView(wallet: wallet)
                CashuTransactionListView(wallet: wallet)
            }
        }
        .networkStatus()  // Show offline banner
        .requireBiometricAuth()  // Face ID/Touch ID
    }
}
```

// Melt tokens via Lightning (pay a BOLT11 invoice)
let meltResult = try await wallet.melt(
    paymentRequest: "lnbc5u1p3...",
    method: "bolt11"
)
```

### Metrics and Logging

- The logger supports categories and levels with sensitive-field redaction by default.
- Metrics are optional via `MetricsSink`. For development:

```swift
logger.setMetricsSink(ConsoleMetricsSink())
logger.metricIncrement("cashukit.example.counter", by: 1, tags: ["env": "dev"]) // optional manual metric
```

Production apps should provide a custom sink that forwards to your telemetry (e.g., StatsD, OpenTelemetry).

## Advanced Features

### Deterministic Secrets (NUT-13)

```swift
// Create wallet with mnemonic for backup/restore
let mnemonic = try CashuWallet.generateMnemonic()
let wallet = try await CashuWallet(
    configuration: config,
    mnemonic: mnemonic
)

// Restore wallet from mnemonic
let restoredWallet = try await CashuWallet(
    configuration: config,
    mnemonic: savedMnemonic
)
```

### Spending Conditions (NUT-10/11)

Support exists in lower-level services and models; high-level wallet helpers are under development. Refer to NUT-10/11 modules and tests for current usage patterns.

### HTLC Support (NUT-14)

HTLC primitives are implemented in the model layer. High-level wallet flows are planned; see NUT-14 tests for examples.

### Token State Management (NUT-07)

```swift
// Check proof states
let batch = try await wallet.checkProofStates(myProofs)
for result in batch.results {
    print("Proof \(try result.proof.calculateY()): \(result.stateInfo.state)")
}

// Restore from seed (NUT-13)
let restoredBalance = try await wallet.restoreFromSeed(batchSize: 100) { progress in
    // handle progress updates
}
```

## Security Considerations

⚠️ **This library is NOT security audited and should NOT be used in production.**

Current security implementation:
- Uses system-provided secure random generation
- Implements constant-time cryptographic operations via P256K
- Validates all external inputs
- Uses actor model for thread safety

Missing security features:
- Secure key storage (Keychain integration in progress)
- Rate limiting for mint requests
- Circuit breakers for network failures
- Comprehensive input validation
- Security audit

## Platform Support

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 10.0+
- visionOS 2.0+

## Dependencies

- [swift-secp256k1](https://github.com/21-DOT-DEV/swift-secp256k1) - Elliptic curve cryptography
- [BigInt](https://github.com/attaswift/BigInt) - Large number arithmetic
- [BitcoinDevKit](https://github.com/bitcoindevkit/bdk-swift) - Bitcoin functionality
- [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) - Additional cryptographic functions
- [SwiftCBOR](https://github.com/valpackett/SwiftCBOR) - CBOR encoding/decoding

## Testing

Run tests using Swift Package Manager:

```bash
swift test
```

Or in Xcode:
- ⌘+U to run all tests

## Contributing

We welcome contributions! However, please note that this library is not yet production ready. Areas that need work:

1. Security hardening and audit
2. Complete test coverage
3. Performance optimization
4. Documentation improvements
5. Missing NUT implementations

Please open an issue to discuss major changes before submitting a PR.

## License

CashuKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Cashu Protocol](https://docs.cashu.space) - The underlying ecash protocol
- [cashubtc/nuts](https://github.com/cashubtc/nuts) - Protocol specifications
- [cashubtc/cdk](https://github.com/cashubtc/cdk) - Reference implementation

---

**Remember**: This is experimental software. Use at your own risk and only with testnet funds.
