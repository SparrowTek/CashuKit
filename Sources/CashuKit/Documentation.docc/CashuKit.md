# ``CashuKit``

Native Apple platform SDK for building Cashu ecash wallets on iOS, macOS, tvOS, watchOS, and visionOS.

## Overview

CashuKit provides deep integration with Apple platforms for building privacy-preserving ecash applications. Built on top of CoreCashu, it adds Keychain-based secure storage, biometric authentication, network monitoring, and background task support.

### Key Features

- **Keychain Storage**: Hardware-backed secure storage with Secure Enclave support
- **Biometric Authentication**: Face ID, Touch ID, and Optic ID support
- **Network Monitoring**: Automatic offline queueing and retry
- **Background Tasks**: Continue operations when app is backgrounded
- **Privacy-Preserving Logging**: Automatic sensitive data redaction

### Getting Started

```swift
import CashuKit

// Create wallet with Apple platform defaults
let wallet = await AppleCashuWallet()

// Connect to a mint
try await wallet.connect(to: URL(string: "https://testnut.cashu.space")!)

// Check balance
let balance = await wallet.balance
print("Balance: \(balance) sats")

// Send tokens
let token = try await wallet.send(amount: 100)
print("Token: \(try wallet.encodeToken(token))")

// Receive tokens
let proofs = try await wallet.receive(token: receivedTokenString)
```

## Topics

### Essentials

- ``AppleCashuWallet``
- <doc:GettingStarted>

### Guides

- <doc:Architecture>
- <doc:Security>

### Platform Integration

- ``KeychainSecureStore``
- ``BiometricAuthManager``
- ``NetworkMonitor``
- ``BackgroundTaskManager``

### Logging

- ``OSLogLogger``

## Requirements

- iOS 17.0+ / macOS 15.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Xcode 16.0+
- Swift 6.0+

## See Also

- [CashuKit Documentation](Documentation/)
- [Cashu Protocol](https://docs.cashu.space)
