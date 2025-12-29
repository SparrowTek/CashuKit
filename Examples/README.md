# CashuKit Examples

Code examples demonstrating how to use CashuKit for building Cashu wallets on Apple platforms.

## Examples

### [BasicWalletSetup.swift](BasicWalletSetup.swift)
- Creating wallets with default and custom configurations
- SwiftUI integration patterns
- Biometric authentication setup
- App group sharing for extensions
- Platform-specific considerations

### [WalletOperations.swift](WalletOperations.swift)
- Minting tokens from Lightning invoices
- Sending tokens to other users
- Receiving tokens
- Melting tokens (paying Lightning)
- Balance checking and denomination breakdown
- Comprehensive error handling

### [BackupRestore.swift](BackupRestore.swift)
- Generating mnemonic backups
- Displaying existing backup phrases
- Restoring wallets from mnemonics
- SwiftUI backup/restore flows
- Multi-mint restoration

## Quick Start

```swift
import CashuKit

// 1. Create wallet
let wallet = await AppleCashuWallet()

// 2. Connect to mint
try await wallet.connect(to: URL(string: "https://testnut.cashu.space")!)

// 3. Check balance
print("Balance: \(await wallet.balance) sats")

// 4. Send tokens
let token = try await wallet.send(amount: 100)
let tokenString = try wallet.encodeToken(token)

// 5. Receive tokens
let proofs = try await wallet.receive(token: receivedTokenString)
```

## SwiftUI Integration

```swift
import SwiftUI
import CashuKit

@main
struct MyApp: App {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some Scene {
        WindowGroup {
            WalletView()
                .environmentObject(wallet)
        }
    }
}

struct WalletView: View {
    @EnvironmentObject var wallet: AppleCashuWallet
    
    var body: some View {
        VStack {
            Text("\(wallet.balance) sats")
                .font(.largeTitle)
            
            Button("Send 100 sats") {
                Task {
                    let token = try await wallet.send(amount: 100)
                    // Share token...
                }
            }
        }
    }
}
```

## Configuration Options

```swift
let config = AppleCashuWallet.Configuration(
    // Share with app extensions
    keychainAccessGroup: "group.com.yourapp.cashu",
    
    // Require biometrics
    enableBiometrics: true,
    
    // Keep local only (recommended)
    enableiCloudSync: false
)

let wallet = await AppleCashuWallet(configuration: config)
```

## Security Notes

- CashuKit stores sensitive data (mnemonics, seeds) in the iOS/macOS Keychain
- Enable biometric authentication for production apps
- Never log or display mnemonics without user authentication
- Test on real devices (simulator has limited Keychain support)

## Documentation

- [Getting Started Guide](../Sources/CashuKit/Documentation.docc/GettingStarted.md)
- [Architecture Overview](../Sources/CashuKit/Documentation.docc/Architecture.md)
- [Security Guide](../Sources/CashuKit/Documentation.docc/Security.md)
- [Apple Integration Guide](../Documentation/AppleIntegrationGuide.md)
