# CashuKit

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-blue.svg)](https://developer.apple.com)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Swift package implementing the Cashu ecash protocol for iOS and Apple platforms. CashuKit provides a simple, type-safe API for integrating Cashu wallet functionality into your applications.

## Features

- ✅ **Complete NUT Implementation**: Supports NUT-00 through NUT-06
- ✅ **Thread-Safe**: Built with Swift's actor model for concurrent operations
- ✅ **Type-Safe**: Leverages Swift's type system for compile-time safety
- ✅ **SwiftUI Ready**: Designed for easy integration with SwiftUI applications
- ✅ **Comprehensive Testing**: Extensive test coverage for all core functionality
- ✅ **Real-time Balance Updates**: Stream balance changes for reactive UIs
- ✅ **Denomination Optimization**: Smart denomination management for efficiency
- ✅ **Error Handling**: Structured error handling with detailed error information

## Supported Cashu NIPs (NUTs)

- **NUT-00**: Blind Diffie-Hellman Key Exchange (BDHKE)
- **NUT-01**: Mint public key exchange
- **NUT-02**: Keysets and fees
- **NUT-03**: Swap tokens
- **NUT-04**: Mint tokens
- **NUT-05**: Melting tokens
- **NUT-06**: Mint information

## Installation

### Swift Package Manager

Add CashuKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/CashuKit", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/your-repo/CashuKit`
3. Choose your version requirements

## Quick Start

```swift
import CashuKit

// Create a wallet
let wallet = await CashuKit.createWallet(mintURL: "https://mint.example.com")

// Initialize the wallet
try await wallet.initialize()

// Check balance
let balance = try await wallet.balance
print("Current balance: \(balance) sats")

// Mint tokens from Lightning invoice
let mintResult = try await wallet.mint(
    amount: 1000, 
    paymentRequest: "lnbc10u1p3..."
)

// Send tokens
let token = try await wallet.send(amount: 500, memo: "Payment for coffee")
let serializedToken = try await wallet.exportToken(amount: 500)

// Receive tokens
let receivedProofs = try await wallet.importToken(serializedToken)

// Spend tokens via Lightning
let meltResult = try await wallet.melt(paymentRequest: "lnbc5u1p3...")
```

## Usage

### Basic Wallet Setup

```swift
import CashuKit

class WalletManager {
    private var wallet: CashuWallet?
    
    func setupWallet() async throws {
        // Create wallet with mint URL
        wallet = await CashuKit.createWallet(
            mintURL: "https://mint.example.com",
            unit: "sat"
        )
        
        // Initialize wallet (fetches mint info and keysets)
        try await wallet?.initialize()
    }
    
    func getBalance() async throws -> Int {
        guard let wallet = wallet else { 
            throw CashuError.walletNotInitialized 
        }
        
        return try await wallet.balance
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import CashuKit

struct WalletView: View {
    @StateObject private var walletManager = WalletManager()
    @State private var balance: Int = 0
    
    var body: some View {
        VStack {
            Text("Balance: \(balance) sats")
                .font(.largeTitle)
            
            Button("Refresh") {
                Task {
                    balance = try await walletManager.getBalance()
                }
            }
        }
        .task {
            try await walletManager.setupWallet()
            balance = try await walletManager.getBalance()
        }
    }
}
```

### Real-time Balance Updates

```swift
// Monitor balance changes in real-time
for await update in wallet.getBalanceStream() {
    if update.balanceChanged {
        print("Balance: \(update.previousBalance) → \(update.newBalance)")
        print("Change: \(update.balanceDifference) sats")
    }
    
    if let error = update.error {
        print("Balance update error: \(error)")
    }
}
```

### Advanced Configuration

```swift
let config = WalletConfiguration(
    mintURL: "https://mint.example.com",
    unit: "sat",
    retryAttempts: 5,
    retryDelay: 2.0,
    operationTimeout: 60.0
)

let wallet = await CashuKit.createWallet(configuration: config)
try await wallet.initialize()
```

### Error Handling

```swift
do {
    let balance = try await wallet.balance
    print("Current balance: \(balance) sats")
} catch CashuError.walletNotInitialized {
    print("Please initialize the wallet first")
} catch CashuError.insufficientBalance {
    print("Not enough balance for this operation")
} catch CashuError.networkError(let details) {
    print("Network error: \(details)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Core Operations

### Minting Tokens

```swift
// Mint tokens from Lightning invoice
let mintResult = try await wallet.mint(
    amount: 1000,
    paymentRequest: "lnbc10u1p3pnyh8n..."
)

print("Minted \(mintResult.proofs.count) proofs")
```

### Sending Tokens

```swift
// Create token for sending
let token = try await wallet.send(amount: 500, memo: "Coffee payment")

// Export as string for sharing
let serializedToken = try await wallet.exportToken(
    amount: 500,
    memo: "Coffee payment"
)

// Share serializedToken with recipient
```

### Receiving Tokens

```swift
// Receive token from string
let proofs = try await wallet.importToken(serializedToken)
print("Received \(proofs.count) proofs")

// Or receive CashuToken directly
let receivedProofs = try await wallet.receive(token: cashuToken)
```

### Spending Tokens

```swift
// Spend tokens via Lightning
let meltResult = try await wallet.melt(
    paymentRequest: "lnbc5u1p3pnyh8n..."
)

if meltResult.settled {
    print("Payment successful")
} else {
    print("Payment pending")
}
```

## Denomination Management

CashuKit includes intelligent denomination management for optimal proof efficiency:

```swift
// Get denomination breakdown
let breakdown = try await wallet.getDenominationBreakdown()
print("Denominations: \(breakdown.denominations)")

// Optimize denominations
let result = try await wallet.optimizeDenominations(
    preferredDenominations: DenominationUtils.standardDenominations
)

// Check if denominations are efficient
let isEfficient = DenominationUtils.isEfficient(breakdown.denominations)
```

## Balance Management

```swift
// Get total balance
let totalBalance = try await wallet.balance

// Get balance for specific keyset
let keysetBalance = try await wallet.balance(for: keysetID)

// Get detailed balance breakdown
let breakdown = try await wallet.getBalanceBreakdown()
for (keysetID, balance) in breakdown.keysetBalances {
    print("Keyset \(keysetID): \(balance.balance) sats")
}
```

## Wallet Statistics

```swift
let stats = try await wallet.getStatistics()
print("Total balance: \(stats.totalBalance) sats")
print("Proof count: \(stats.proofCount)")
print("Spent proofs: \(stats.spentProofCount)")
print("Keysets: \(stats.keysetCount)")
```

## Platform Support

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 10.0+
- visionOS 2.0+

## Architecture

CashuKit is built with modern Swift practices:

- **Actor-based Concurrency**: Thread-safe operations using Swift's actor model
- **Async/Await**: Modern concurrency with async/await patterns
- **Structured Error Handling**: Comprehensive error types and handling
- **Type Safety**: Leverage Swift's type system for compile-time guarantees
- **Protocol-oriented Design**: Extensible and testable architecture

## Security

- **Secure Random Generation**: Uses system-provided secure random number generation
- **Memory Safety**: Proper cleanup of sensitive cryptographic material
- **Input Validation**: Comprehensive validation of all external inputs
- **TLS Enforcement**: All network communication uses TLS
- **Constant-time Operations**: Cryptographic operations use constant-time implementations

## Testing

Run tests using Swift Package Manager:

```bash
swift test
```

Or in Xcode:
- ⌘+U to run all tests
- Navigate to Test Navigator for individual test runs

## Examples

Check out the `Examples/` directory for comprehensive usage examples:

- **BasicIntegration.swift**: Complete integration example with SwiftUI
- **CommandLineWallet.swift**: Command-line wallet implementation
- **Advanced Examples**: Complex scenarios and edge cases

## Documentation

- **API Documentation**: Complete API reference in `Documentation/API.md`
- **Integration Guide**: Step-by-step integration guide
- **Migration Guide**: Upgrading between versions
- **Troubleshooting**: Common issues and solutions

## Contributing

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

CashuKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Support

- **GitHub Issues**: Report bugs or request features
- **Documentation**: Check the `Documentation/` directory
- **Examples**: See `Examples/` for usage patterns

## Acknowledgments

- [Cashu Protocol](https://docs.cashu.space) - The underlying ecash protocol
- [Swift Secp256k1](https://github.com/21-DOT-DEV/swift-secp256k1) - Cryptographic operations
- The Swift community for excellent tooling and libraries

---

**Note**: This is a Swift implementation of the Cashu ecash protocol. For the complete protocol specification, visit [docs.cashu.space](https://docs.cashu.space).
