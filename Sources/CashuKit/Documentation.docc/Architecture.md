# Architecture

Understand CashuKit's architecture and how it integrates with Apple platforms.

## Overview

CashuKit is a platform-specific SDK built on top of CoreCashu. It provides Apple-native implementations for secure storage, authentication, networking, and background processing.

### Architectural Layers

```
┌─────────────────────────────────────────┐
│           Your iOS/macOS App            │
│         (Your UI goes here)             │
├─────────────────────────────────────────┤
│              CashuKit                   │  ← You are here
│   AppleCashuWallet, KeychainSecureStore │
│   BiometricAuthManager, NetworkMonitor  │
├─────────────────────────────────────────┤
│              CoreCashu                  │
│    (Platform-Agnostic Protocol)         │
│   CashuWallet, NUT implementations      │
└─────────────────────────────────────────┘
```

## Core Components

### AppleCashuWallet

The main entry point for CashuKit. It wraps CoreCashu's `CashuWallet` and adds Apple platform integration:

```swift
// AppleCashuWallet provides:
// - Automatic Keychain storage
// - Biometric authentication hooks
// - Network monitoring integration
// - Background task support

let wallet = await AppleCashuWallet()
try await wallet.connect(to: mintURL)
```

### KeychainSecureStore

Implements CoreCashu's `SecureStore` protocol using iOS/macOS Keychain:

- Hardware-backed encryption via Secure Enclave
- Biometric protection (Face ID / Touch ID / Optic ID)
- Optional iCloud Keychain sync
- App group sharing for extensions

```swift
let store = KeychainSecureStore(
    accessGroup: "group.com.yourapp.cashu"
)
```

### BiometricAuthManager

Handles Local Authentication framework integration:

```swift
let bioManager = BiometricAuthManager.shared

// Check availability
await bioManager.checkBiometricAvailability()

// Authenticate
if await bioManager.isAvailable {
    try await bioManager.authenticateUser(
        reason: "Access your wallet"
    )
}
```

### NetworkMonitor

Monitors network connectivity using Network framework:

```swift
let monitor = await NetworkMonitor()
await monitor.startMonitoring()

// Check status
if await monitor.isConnected {
    // Online - proceed normally
} else {
    // Offline - queue operation
    await monitor.queueOperation(type: .sendToken, data: data)
}
```

### BackgroundTaskManager

Manages BGTaskScheduler for background operations:

```swift
let manager = BackgroundTaskManager(networkMonitor: monitor)
await manager.registerBackgroundTasks()

// Schedule background refresh
try await manager.scheduleBackgroundTask(.balanceRefresh)
```

### OSLogLogger

Privacy-preserving logger using os.log:

```swift
let logger = OSLogLogger(
    category: "Wallet",
    minimumLevel: .info
)

// Sensitive data is automatically redacted
logger.info("Sending transaction to mint")
```

### AppleWebSocketClient

NUT-17 WebSocket support is provided by `AppleWebSocketClient`:

- `connect(to:)` performs a ping probe before marking the client connected.
- `isConnected` only becomes `true` after connection validation succeeds.
- `send`, `receive`, and `ping` are bounded by `WebSocketConfiguration.connectionTimeout`.

```swift
let wsClient = AppleWebSocketClient(
    configuration: WebSocketConfiguration(connectionTimeout: 10)
)

try await wsClient.connect(to: wsURL)
```

## Data Flow

### Minting Flow

```
User                    AppleCashuWallet           CoreCashu              Mint
  │                           │                       │                    │
  │── requestMintQuote() ────►│                       │                    │
  │                           │── requestMintQuote() ─►│                    │
  │                           │                       │── POST /mint/quote ►│
  │                           │                       │◄── quote + invoice ─│
  │◄── quote + invoice ───────│                       │                    │
  │                           │                       │                    │
  │   [User pays invoice]     │                       │                    │
  │                           │                       │                    │
  │── mint(quoteId) ─────────►│                       │                    │
  │                           │── KeychainSecureStore │                    │
  │                           │   [load seed]         │                    │
  │                           │── mint(quoteId) ─────►│                    │
  │                           │                       │── POST /mint ──────►│
  │                           │                       │◄── blind sigs ──────│
  │                           │◄── proofs ────────────│                    │
  │                           │── KeychainSecureStore │                    │
  │                           │   [store proofs]      │                    │
  │◄── proofs ────────────────│                       │                    │
```

### Offline Queueing

```
User                    AppleCashuWallet           NetworkMonitor
  │                           │                       │
  │── send(amount) ──────────►│                       │
  │                           │── isConnected? ──────►│
  │                           │◄── false ─────────────│
  │                           │── queueOperation() ──►│
  │                           │                       │── [store in Keychain]
  │◄── queued ────────────────│                       │
  │                           │                       │
  │   [Network restored]      │                       │
  │                           │◄── connectionPublisher│
  │                           │── processQueue() ────►│
  │                           │                       │── [execute operations]
```

## Threading Model

CashuKit uses Swift's structured concurrency:

1. **AppleCashuWallet** - Actor-isolated, serializes all operations
2. **NetworkMonitor** - Actor-isolated, manages network state
3. **BackgroundTaskManager** - Actor-isolated, manages tasks
4. **KeychainSecureStore** - Thread-safe via Sendable conformance

All public APIs are `async` and safe to call from any context.

## Security Architecture

### Storage Security

```
┌──────────────────────────────────────┐
│            Keychain                  │
├──────────────────────────────────────┤
│  Mnemonic    [Biometric Protected]   │
│  Seed        [Biometric Protected]   │
│  Access Tokens [Per-mint]            │
│  Queued Operations [Encrypted]       │
└──────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│        Secure Enclave                │
│   (Hardware key storage)             │
└──────────────────────────────────────┘
```

### Data Protection

- All sensitive data stored in Keychain
- Biometric authentication for wallet access
- Automatic memory zeroization for secrets
- Privacy-preserving logs (auto-redaction)

## Platform Support

| Feature | iOS | macOS | tvOS | watchOS | visionOS |
|---------|-----|-------|------|---------|----------|
| Keychain | ✅ | ✅ | ✅ | ✅ | ✅ |
| Face ID | ✅ | ✅ | - | - | - |
| Touch ID | ✅ | ✅ | - | - | - |
| Optic ID | - | - | - | - | ✅ |
| Background Tasks | ✅ | ✅ | - | ✅ | ✅ |
| Network Monitor | ✅ | ✅ | ✅ | ✅ | ✅ |

## See Also

- ``AppleCashuWallet``
- ``KeychainSecureStore``
- ``BiometricAuthManager``
- <doc:Security>
