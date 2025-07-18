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

A Swift package implementing the Cashu ecash protocol for iOS and Apple platforms. CashuKit provides a type-safe API for integrating Cashu wallet functionality into your applications.

## Current Status

This library is approximately 60-70% complete. See [Production_Ready_Analysis.md](Production_Ready_Analysis.md) for a detailed assessment of what's implemented and what remains.

### ✅ Implemented
- **Core Protocol**: NUT-00 through NUT-06, NUT-07, NUT-08, NUT-09, NUT-10, NUT-11, NUT-12, NUT-13, NUT-14, NUT-15, NUT-16, NUT-17, NUT-19, NUT-20, NUT-22
- **Wallet Operations**: Mint, melt, swap, send, receive
- **Token Management**: V3/V4 token serialization, CBOR support
- **Cryptography**: BDHKE, deterministic secrets, P2PK, HTLCs
- **State Management**: Actor-based concurrency, thread safety
- **Error Handling**: Comprehensive error types and recovery

### 🚧 In Progress
- **Security**: Keychain integration via Vault framework
- **Authentication**: NUT-22 access token support
- **Restoration**: Full wallet restoration from mnemonic

### ❌ Not Implemented
- **Advanced Features**: DLCs, subscription model
- **Production Hardening**: Rate limiting, circuit breakers
- **Testing**: Full test coverage, integration tests

## Features

- ✅ **NUT Implementation**: Supports NUT-00 through NUT-22 (with some gaps)
- ✅ **Thread-Safe**: Built with Swift's actor model for concurrent operations
- ✅ **Type-Safe**: Leverages Swift's type system for compile-time safety
- ✅ **SwiftUI Ready**: Designed for easy integration with SwiftUI applications
- ✅ **Deterministic Secrets**: BIP39/BIP32 support for wallet recovery
- ✅ **Multiple Token Formats**: V3 JSON and V4 CBOR token formats
- ✅ **Advanced Spending Conditions**: P2PK and HTLC support

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

Add CashuKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CashuKit", from: "0.1.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/SparrowTek/CashuKit`
3. Choose your version requirements

## Quick Start

```swift
import CashuKit

// Create wallet configuration
let config = WalletConfiguration(
    mintURL: "https://testnut.cashu.space",
    unit: "sat"
)

// Create a wallet
let wallet = await CashuWallet(configuration: config)

// Initialize the wallet
try await wallet.initialize()

// Check balance
let balance = await wallet.getTotalBalance()
print("Current balance: \(balance) sats")

// Mint tokens from Lightning invoice
let mintQuote = try await wallet.requestMintQuote(amount: 1000)
// Pay the Lightning invoice...
let proofs = try await wallet.mint(quoteID: mintQuote.quote)

// Send tokens
let token = try await wallet.send(amount: 500, memo: "Payment for coffee")

// Receive tokens
let receivedProofs = try await wallet.receive(token: token)

// Melt tokens via Lightning
let meltQuote = try await wallet.requestMeltQuote(
    paymentRequest: "lnbc5u1p3...",
    amount: 500
)
let meltResult = try await wallet.melt(quote: meltQuote)
```

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

```swift
// Create P2PK-locked token
let publicKey = try P256K.KeyAgreement.PrivateKey().publicKey
let p2pkToken = try await wallet.send(
    amount: 1000,
    conditions: .p2pk(publicKey: publicKey)
)

// Receive P2PK token with signature
let signature = try wallet.createP2PKSignature(
    privateKey: privateKey,
    proofs: p2pkToken.token[0].proofs
)
let proofs = try await wallet.receive(
    token: p2pkToken,
    p2pkSignatures: [signature]
)
```

### HTLC Support (NUT-14)

```swift
// Create HTLC-locked token
let htlcSecret = "mySecret"
let htlcToken = try await wallet.send(
    amount: 500,
    conditions: .htlc(
        hashlock: SHA256.hash(data: htlcSecret.data(using: .utf8)!),
        locktime: Date().timeIntervalSince1970 + 3600 // 1 hour
    )
)

// Claim HTLC token
let htlcProofs = try await wallet.receive(
    token: htlcToken,
    htlcPreimages: [htlcSecret]
)
```

### Token State Management (NUT-07)

```swift
// Check proof states
let states = try await wallet.checkProofStates(proofs: myProofs)
for state in states {
    print("Proof \(state.Y): \(state.state)")
}

// Restore proofs from deterministic backup
let restoredProofs = try await wallet.restore(
    keysetIDs: ["009a1f293253e41e"],
    startCounter: 0,
    maxCounter: 1000
)
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