# Getting Started with CashuKit

Create your first Cashu wallet on Apple platforms.

## Overview

This guide walks you through setting up a CashuKit wallet, connecting to a mint, and performing basic operations like sending and receiving tokens.

## Prerequisites

- Xcode 16.0 or later
- iOS 17.0+ / macOS 15.0+ target
- Swift Package Manager

## Installation

Add CashuKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/SparrowTek/CashuKit", from: "0.1.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Creating a Wallet

### Basic Setup

```swift
import CashuKit

// Create wallet with Apple platform defaults
let wallet = await AppleCashuWallet()

// Connect to a mint
let mintURL = URL(string: "https://testnut.cashu.space")!
try await wallet.connect(to: mintURL)
```

### With Custom Configuration

```swift
let config = AppleCashuWallet.Configuration(
    keychainAccessGroup: "group.com.yourapp.cashu",
    enableBiometrics: true,
    enableiCloudSync: false
)

let wallet = await AppleCashuWallet(configuration: config)
```

## Checking Balance

```swift
// Get current balance
let balance = await wallet.balance
print("Balance: \(balance) sats")

// Check if connected
if wallet.isConnected {
    print("Connected to: \(wallet.currentMintURL?.absoluteString ?? "unknown")")
}
```

## Minting Tokens

To create new tokens, you pay a Lightning invoice:

```swift
// Request a mint quote
let quote = try await wallet.requestMintQuote(amount: 1000)

// Display the invoice for the user to pay
print("Pay this invoice: \(quote.request)")

// After payment, mint the tokens
let proofs = try await wallet.mint(quoteId: quote.quote)
print("Minted \(proofs.count) proofs")
```

## Sending Tokens

Create a token string to share with someone:

```swift
// Create a token for 100 sats
let token = try await wallet.send(amount: 100, memo: "Payment for coffee")

// Get the serialized token string
let tokenString = try wallet.encodeToken(token)
print("Send this token: \(tokenString)")
```

## Receiving Tokens

Process a token received from another user:

```swift
// Receive a token string
let receivedToken = "cashuA..."

let proofs = try await wallet.receive(token: receivedToken)
print("Received \(proofs.count) proofs")

// Balance is automatically updated
print("New balance: \(await wallet.balance) sats")
```

## Melting Tokens (Paying Lightning)

Pay a Lightning invoice using your tokens:

```swift
let invoice = "lnbc..."

// Get a quote for the payment
let quote = try await wallet.requestMeltQuote(request: invoice)
print("Amount: \(quote.amount), Fee: \(quote.feeReserve)")

// Execute the payment
let result = try await wallet.melt(quoteId: quote.quote)

if result.paid {
    print("Payment successful!")
}
```

## Wallet Backup and Restore

### Generate Mnemonic

```swift
// Generate a new mnemonic for backup
let mnemonic = try await wallet.generateMnemonic()
print("Save these words: \(mnemonic)")
```

### Restore from Mnemonic

```swift
// Restore wallet from mnemonic
try await wallet.restore(mnemonic: savedMnemonic)

// Wallet will scan the mint for your proofs
print("Restored balance: \(await wallet.balance) sats")
```

## SwiftUI Integration

```swift
import SwiftUI
import CashuKit

struct WalletView: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\(wallet.balance) sats")
                .font(.largeTitle)
            
            if wallet.isLoading {
                ProgressView()
            }
            
            Button("Refresh") {
                Task {
                    await wallet.refreshBalance()
                }
            }
        }
        .task {
            try? await wallet.connect(
                to: URL(string: "https://testnut.cashu.space")!
            )
        }
    }
}
```

## Error Handling

```swift
do {
    let token = try await wallet.send(amount: 100)
} catch let error as CashuError {
    switch error {
    case .insufficientBalance(let required, let available):
        print("Need \(required) sats, have \(available)")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## Next Steps

- Read the <doc:Architecture> guide to understand CashuKit's design
- Review <doc:Security> for security best practices
- See the [AppleIntegrationGuide](../../Documentation/AppleIntegrationGuide.md) for platform-specific features
