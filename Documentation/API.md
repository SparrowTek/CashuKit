# CashuKit API Documentation

## Overview

CashuKit is a Swift package that provides a complete implementation of the Cashu ecash protocol for iOS and Apple platforms. It offers a simple, type-safe API for integrating Cashu wallet functionality into your applications.

## Installation

### Swift Package Manager

Add CashuKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CashuKit", from: "0.1.0")
]
```

## Quick Start

```swift
import CashuKit

// Create a wallet and initialize
let wallet = await CashuKit.createWallet(mintURL: "https://testnut.cashu.space")
try await wallet.initialize()

// Query balance
let balance = try await wallet.balance
print("Balance: \(balance)")

// Mint tokens (BOLT11)
let mintResult = try await wallet.mint(amount: 1000, paymentRequest: "lnbc...")

// Send and receive
let token = try await wallet.send(amount: 500, memo: "Payment for coffee")
let receivedProofs = try await wallet.receive(token: token)
```

## Core Classes

### CashuKit

The main entry point for the library.

#### Static Methods

##### `createWallet(mintURL:unit:) async -> CashuWallet`
Creates a new wallet instance with the specified mint URL.

**Parameters:**
- `mintURL: String` - The URL of the mint to connect to
- `unit: String` - Currency unit (default: "sat")

**Returns:** `CashuWallet` - Initialized wallet instance

##### `createWallet(configuration:) async -> CashuWallet`
Creates a new wallet with custom configuration.

**Parameters:**
- `configuration: WalletConfiguration` - Wallet configuration

**Returns:** `CashuWallet` - Initialized wallet instance

##### `validateMintURL(_ mintURL: String) -> Bool`
Validates if a mint URL is properly formatted.

**Parameters:**
- `mintURL: String` - URL to validate

**Returns:** `Bool` - True if valid, false otherwise

##### `validateToken(_ token: CashuToken) -> Bool`
Validates if a Cashu token is properly formatted.

**Parameters:**
- `token: CashuToken` - Token to validate

**Returns:** `Bool` - True if valid, false otherwise

### CashuWallet

The main wallet actor that manages all wallet operations.

#### Properties

##### `state: WalletState { get }`
Current wallet state (uninitialized, initializing, ready, syncing, error).

##### `isReady: Bool { get }`
Whether the wallet is ready for operations.

##### `balance: Int { get async throws }`
Current total balance in the wallet.

##### `proofs: [Proof] { get async throws }`
All available proofs in the wallet.

##### `mintInfo: MintInfo? { get }`
Information about the connected mint.

##### `keysets: [String: Keyset] { get }`
Currently available keysets.

#### Initialization

##### `init(mintURL: String, unit: String = "sat") async`
Initialize wallet with mint URL and currency unit.

##### `init(configuration: WalletConfiguration, proofStorage: ProofStorage? = nil) async`
Initialize wallet with custom configuration and optional proof storage.

##### `initialize() async throws`
Initialize the wallet by fetching mint information and keysets.

##### `sync() async throws`
Synchronize wallet state with the mint.

#### Core Operations

##### `mint(amount: Int, paymentRequest: String, method: String = "bolt11") async throws -> MintResult`
Mint new tokens from a payment request.

**Parameters:**
- `amount: Int` - Amount to mint
- `paymentRequest: String` - Payment request (e.g., Lightning invoice)
- `method: String` - Payment method (default: "bolt11")

**Returns:** `MintResult` - Result with new proofs

##### `send(amount: Int, memo: String? = nil) async throws -> CashuToken`
Prepare tokens for sending.

**Parameters:**
- `amount: Int` - Amount to send
- `memo: String?` - Optional memo

**Returns:** `CashuToken` - Token ready for transfer

##### `receive(token: CashuToken) async throws -> [Proof]`
Receive tokens from another wallet.

**Parameters:**
- `token: CashuToken` - Token to receive

**Returns:** `[Proof]` - Array of new proofs

##### `melt(paymentRequest: String, method: String = "bolt11") async throws -> MeltResult`
Spend tokens via Lightning Network.

**Parameters:**
- `paymentRequest: String` - Lightning payment request
- `method: String` - Payment method (default: "bolt11")

**Returns:** `MeltResult` - Result of the melt operation

#### Balance Management

##### `balance(for keysetID: String) async throws -> Int`
Get balance for a specific keyset.

##### `getBalanceBreakdown() async throws -> BalanceBreakdown`
Get detailed balance breakdown by keyset.

##### `getBalanceStream() -> AsyncStream<BalanceUpdate>`
Get real-time balance updates.

#### Token Management

##### `importToken(_ serializedToken: String) async throws -> [Proof]`
Import a token from a serialized string.

##### `exportToken(amount: Int, memo: String? = nil, version: TokenVersion = .v3, includeURI: Bool = false) async throws -> String`
Export a token with specified amount.

##### `exportAllTokens(memo: String? = nil, version: TokenVersion = .v3, includeURI: Bool = false) async throws -> String`
Export all available tokens.

##### `createToken(from proofs: [Proof], memo: String? = nil) async throws -> CashuToken`
Create a token from existing proofs.

#### Denomination Management

##### `getAvailableDenominations() async throws -> [Int]`
Get available denominations in the wallet.

##### `getDenominationBreakdown() async throws -> DenominationBreakdown`
Get detailed denomination breakdown.

##### `optimizeDenominations(preferredDenominations: [Int]) async throws -> OptimizationResult`
Optimize denominations by swapping to preferred amounts.

##### `getRecommendedDenominations(for amount: Int) -> [Int: Int]`
Get recommended denomination structure for a given amount.

#### Utility Methods

##### `clearAll() async throws`
Clear all wallet data.

##### `getStatistics() async throws -> WalletStatistics`
Get wallet statistics and information.

## Configuration

### WalletConfiguration

Configuration object for wallet initialization.

```swift
public struct WalletConfiguration: Sendable {
    public let mintURL: String
    public let unit: String
    public let retryAttempts: Int
    public let retryDelay: TimeInterval
    public let operationTimeout: TimeInterval
    
    public init(
        mintURL: String,
        unit: String = "sat",
        retryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0,
        operationTimeout: TimeInterval = 30.0
    )
}
```

## Data Types

### Core Types

#### `CashuToken`
Represents a Cashu token that can be transferred between wallets.

#### `Proof`
Represents a cryptographic proof of ownership for a specific amount.

#### `MintInfo`
Information about a mint's capabilities and configuration.

#### `Keyset`
Cryptographic keys used by the mint for a specific currency unit.

### Result Types

#### `MintResult`
Result of a mint operation.

#### `MeltResult`
Result of a melt operation.

#### `BalanceBreakdown`
Detailed balance information by keyset.

#### `WalletStatistics`
Comprehensive wallet statistics.

#### `OptimizationResult`
Result of denomination optimization.

### State Types

#### `WalletState`
Current state of the wallet:
- `.uninitialized` - Wallet not yet initialized
- `.initializing` - Wallet is initializing
- `.ready` - Wallet ready for operations
- `.syncing` - Wallet is syncing with mint
- `.error(CashuError)` - Wallet encountered an error

## Error Handling

CashuKit uses structured error handling with the `CashuError` enum:

```swift
do {
    let balance = try await wallet.balance
} catch CashuError.walletNotInitialized {
    print("Wallet needs to be initialized first")
} catch CashuError.insufficientBalance {
    print("Not enough balance for this operation")
} catch {
    print("Unexpected error: \(error)")
}
```

Common error types:
- `walletNotInitialized` - Operation attempted on uninitialized wallet
- `insufficientBalance` - Not enough balance for operation
- `invalidAmount` - Invalid amount specified
- `invalidMintConfiguration` - Mint configuration is invalid
- `networkError` - Network-related errors
- `cryptographicError` - Cryptographic operation failed

## Best Practices

### 1. Always Initialize
```swift
let wallet = await CashuKit.createWallet(mintURL: "https://mint.example.com")
try await wallet.initialize()
```

### 2. Handle State Changes
```swift
switch wallet.state {
case .ready:
    // Wallet is ready for operations
    break
case .error(let error):
    // Handle error
    print("Wallet error: \(error)")
default:
    // Handle other states
    break
}
```

### 3. Use Real-time Balance Updates
```swift
for await update in wallet.getBalanceStream() {
    if update.balanceChanged {
        print("Balance changed: \(update.balanceDifference)")
    }
}
```

### 4. Validate Inputs
```swift
guard CashuKit.validateMintURL(mintURL) else {
    throw ValidationError.invalidMintURL
}
```

### 5. Optimize Denominations
```swift
let breakdown = try await wallet.getDenominationBreakdown()
if !DenominationUtils.isEfficient(breakdown.denominations) {
    let result = try await wallet.optimizeDenominations(
        preferredDenominations: DenominationUtils.standardDenominations
    )
}
```

## Platform Support

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 10.0+
- visionOS 2.0+

## Thread Safety

CashuKit is built with Swift's actor model, ensuring thread safety:
- `CashuWallet` is an actor, all operations are automatically serialized
- All public APIs are marked as `Sendable` where appropriate
- Concurrent operations are safe and well-defined

## Performance Considerations

- Balance calculations are cached and updated incrementally
- Network operations include retry logic with exponential backoff
- Cryptographic operations are optimized using native Swift implementations
- Memory usage is optimized through efficient proof storage

## Security Notes

- Private keys are generated using secure random number generation
- All network communication uses TLS
- Sensitive data is properly cleaned up from memory
- Input validation is performed on all external data

## Migration Guide

When upgrading between versions, refer to the migration guide for breaking changes and new features.

## Support

For questions, issues, or contributions, please visit the GitHub repository or contact the development team.