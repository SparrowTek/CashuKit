# Apple Platform Integration Guide

## Overview

CashuKit provides deep integration with Apple platforms, leveraging native frameworks for security, performance, and user experience. This guide covers platform-specific features and best practices.

## Table of Contents

1. [Platform Requirements](#platform-requirements)
2. [Security & Privacy](#security--privacy)
3. [Keychain Integration](#keychain-integration)
4. [Biometric Authentication](#biometric-authentication)
5. [Network Handling](#network-handling)
6. [Background Execution](#background-execution)
7. [SwiftUI Components](#swiftui-components)
8. [App Extensions](#app-extensions)
9. [Platform-Specific Features](#platform-specific-features)
10. [App Store Submission](#app-store-submission)

## Platform Requirements

### Minimum OS Versions
- iOS 17.0+
- macOS 15.0+
- tvOS 17.0+
- watchOS 10.0+
- visionOS 1.0+

### Required Capabilities
- Keychain Sharing (optional, for app groups)
- Background Modes (optional, for background refresh)
- Face ID/Touch ID Usage

## Security & Privacy

### Info.plist Requirements

```xml
<!-- Required for biometric authentication -->
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your Cashu wallet</string>

<!-- Required for background refresh -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

### App Transport Security

For local/test mints without TLS:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Keychain Integration

### Basic Setup

```swift
// Use default Keychain configuration
let wallet = AppleCashuWallet()

// Custom Keychain configuration
let secureStore = KeychainSecureStore(
    accessGroup: "group.com.yourapp.cashu",
    securityConfiguration: .maximum
)
```

### Security Configurations

```swift
// Standard security (default)
let standard = KeychainSecureStore.SecurityConfiguration.standard

// Maximum security with biometrics
let maximum = KeychainSecureStore.SecurityConfiguration(
    useBiometrics: true,
    useSecureEnclave: true,
    accessibleWhenUnlocked: false,
    synchronizable: false
)

// Custom configuration for iCloud sync
let syncable = KeychainSecureStore.SecurityConfiguration(
    useBiometrics: false,
    useSecureEnclave: true,
    accessibleWhenUnlocked: true,
    synchronizable: true  // Enable iCloud Keychain
)
```

### App Groups for Sharing

```swift
// Share wallet between app and extension
let sharedStore = KeychainSecureStore(
    accessGroup: "group.com.yourapp.shared"
)

// In your app's entitlements:
// keychain-access-groups: ["group.com.yourapp.shared"]
```

## Biometric Authentication

### Setup and Configuration

```swift
// Configure biometric authentication
BiometricAuthManager.shared.configure(
    policy: [.deviceOwnerAuthentication, .sensitiveOperationsOnly]
)

// Check availability
await BiometricAuthManager.shared.checkBiometricAvailability()
let biometricType = await BiometricAuthManager.shared.biometricType

switch biometricType {
case .faceID:
    print("Face ID available")
case .touchID:
    print("Touch ID available")
case .opticID:
    print("Optic ID available (Vision Pro)")
case .none:
    print("No biometric authentication")
}
```

### Requiring Authentication

```swift
// Authenticate before sensitive operation
try await BiometricAuthManager.shared.authenticate(
    reason: "Authenticate to send tokens"
)

// SwiftUI view requiring authentication
struct SecureWalletView: View {
    var body: some View {
        WalletContentView()
            .requireBiometricAuth(
                reason: "Authenticate to access wallet"
            )
    }
}
```

### Keychain with Biometric Protection

```swift
// Store with biometric protection
try await BiometricAuthManager.shared.storeWithBiometricProtection(
    data: sensitiveData,
    account: "wallet_seed",
    service: "com.yourapp.cashu"
)

// Retrieve with biometric authentication
let data = try await BiometricAuthManager.shared.retrieveWithBiometricAuth(
    account: "wallet_seed",
    service: "com.yourapp.cashu",
    reason: "Access wallet seed"
)
```

## Network Handling

### Network Monitoring

```swift
// Monitor network status
let monitor = NetworkMonitor.shared
monitor.startMonitoring()

// Check connectivity
if monitor.isConnected {
    print("Connected via: \(monitor.connectionType.displayName)")
    print("Network quality: \(monitor.currentStatus.qualityScore)")
}

// React to changes
monitor.connectionPublisher
    .sink { isConnected in
        if isConnected {
            // Process queued operations
        }
    }
```

### Offline Operation Queueing

```swift
// Queue operations when offline
NetworkMonitor.shared.queueOperation(
    type: .sendToken,
    data: tokenData,
    priority: .high
)

// Operations automatically process when reconnected
// Or manually trigger:
await NetworkMonitor.shared.processQueuedOperations()
```

### SwiftUI Network Status

```swift
struct ContentView: View {
    var body: some View {
        WalletView()
            .networkStatus()  // Shows offline banner
    }
}
```

## Background Execution

### Register Background Tasks

```swift
// In AppDelegate or App
let networkMonitor = NetworkMonitor()
let backgroundTaskManager = BackgroundTaskManager(networkMonitor: networkMonitor)
backgroundTaskManager.registerBackgroundTasks()
backgroundTaskManager.setupLifecycleObservers()

// Schedule specific tasks
try await backgroundTaskManager.scheduleBackgroundTask(.balanceRefresh)
```

### Background URL Sessions

```swift
// Download with background support
let networkMonitor = NetworkMonitor()
let backgroundTaskManager = BackgroundTaskManager(networkMonitor: networkMonitor)
let task = backgroundTaskManager.startBackgroundDownload(
    from: mintURL
) { result in
    switch result {
    case .success(let data):
        // Process downloaded data
    case .failure(let error):
        // Handle error
    }
}
```

### Handle App Lifecycle

```swift
// Automatically handled, but can customize:
class AppDelegate: NSObject, UIApplicationDelegate {
    let networkMonitor = NetworkMonitor()
    lazy var backgroundTaskManager = BackgroundTaskManager(networkMonitor: networkMonitor)
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        Task {
            await backgroundTaskManager.handleEnterBackground()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        Task {
            await backgroundTaskManager.handleEnterForeground()
        }
    }
}
```

## SwiftUI Components

### Balance View

```swift
struct WalletScreen: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        VStack {
            // Displays balance with connection status
            CashuBalanceView(wallet: wallet)
                .padding()
        }
    }
}
```

### Send/Receive Interface

```swift
struct TransactionView: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        CashuSendReceiveView(wallet: wallet)
            .navigationTitle("Send & Receive")
    }
}
```

### Transaction History

```swift
struct HistoryView: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        CashuTransactionListView(wallet: wallet)
            .searchable(text: $searchText)
            .refreshable {
                await wallet.refreshTransactions()
            }
    }
}
```

### Mint Selection

```swift
struct SettingsView: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        MintSelectionView(wallet: wallet)
            .navigationTitle("Mint Settings")
    }
}
```

## App Extensions

### Widget Extension

```swift
// In your widget
struct CashuWidget: Widget {
    let kind: String = "CashuWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CashuWidgetView(entry: entry)
        }
        .configurationDisplayName("Cashu Balance")
        .description("View your ecash balance")
    }
}

// Share data via app group
let sharedWallet = AppleCashuWallet(
    keychainAccessGroup: "group.com.yourapp.widget"
)
```

### Action Extension

```swift
// Share extension for receiving tokens
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Process shared token
        if let token = extractTokenFromInput() {
            Task {
                let wallet = AppleCashuWallet(
                    keychainAccessGroup: "group.com.yourapp.shared"
                )
                try await wallet.receive(token: token)
            }
        }
    }
}
```

## Platform-Specific Features

### iOS

```swift
#if os(iOS)
// Haptic feedback
import UIKit

func sendTokenWithHaptics() async {
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    
    do {
        let token = try await wallet.send(amount: 100)
        generator.notificationOccurred(.success)
    } catch {
        generator.notificationOccurred(.error)
    }
}

// Share token via system share sheet
func shareToken(_ token: String) {
    let activity = UIActivityViewController(
        activityItems: [token],
        applicationActivities: nil
    )
    present(activity, animated: true)
}
#endif
```

### macOS

```swift
#if os(macOS)
// Menu bar app
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "₿ 0"
            button.action = #selector(showWallet)
        }
    }
    
    func updateBalance(_ balance: Int) {
        statusItem.button?.title = "₿ \(balance)"
    }
}
#endif
```

### visionOS

```swift
#if os(visionOS)
// Spatial computing features
struct ImmersiveWalletView: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        RealityView { content in
            // 3D wallet visualization
            let balanceEntity = createBalanceEntity(wallet.balance)
            content.add(balanceEntity)
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            CashuBalanceView(wallet: wallet)
                .glassBackgroundEffect()
        }
    }
}

// Optic ID authentication
func authenticateWithOpticID() async throws {
    let bioManager = BiometricAuthManager.shared
    await bioManager.checkBiometricAvailability()
    
    if await bioManager.biometricType == .opticID {
        try await bioManager.authenticate(reason: "Look to authenticate")
    }
}
#endif
```

### watchOS

```swift
#if os(watchOS)
// Complication support
struct CashuComplication: View {
    @StateObject private var wallet = AppleCashuWallet()
    
    var body: some View {
        Text("₿ \(wallet.balance)")
            .font(.system(.body, design: .rounded))
    }
}

// Quick actions
struct QuickReceiveView: View {
    var body: some View {
        Button("Receive") {
            // Show QR code on watch
        }
        .buttonStyle(.borderedProminent)
    }
}
#endif
```

## App Store Submission

### Export Compliance

Add to Info.plist:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<true/>
<key>ITSEncryptionExportComplianceCode</key>
<string>YOUR-COMPLIANCE-CODE</string>
```

### App Review Notes

Include in review notes:
- Explanation of ecash and Cashu protocol
- Test mint URL and credentials
- Sample tokens for testing
- Note that no real money is involved in TestFlight

### Privacy Nutrition Label

Declare the following data collection:
- **Identifiers**: Device ID (for wallet identification)
- **Financial Info**: Transaction history (stored locally)
- **Diagnostics**: Crash data, performance data

### Required Descriptions

Ensure clear descriptions for:
- Why Face ID/Touch ID is needed
- What data is stored in Keychain
- Network usage for mint communication
- Background refresh purpose

## Troubleshooting

### Common Issues

1. **Keychain Access Errors**
   - Ensure proper entitlements
   - Check access group configuration
   - Verify app signing

2. **Biometric Authentication Failures**
   - Check Info.plist descriptions
   - Handle fallback to passcode
   - Test on real devices

3. **Background Task Not Running**
   - Verify Info.plist configuration
   - Check task registration
   - Test with Xcode's background fetch simulation

4. **Network Issues**
   - Handle offline scenarios
   - Implement proper retry logic
   - Test with Network Link Conditioner

### Debug Tools

```swift
// Enable verbose logging
let logger = OSLogLogger(category: "Debug", minimumLevel: .debug)

// Monitor background tasks
#if DEBUG
let networkMonitor = NetworkMonitor()
let backgroundTaskManager = BackgroundTaskManager(networkMonitor: networkMonitor)
backgroundTaskManager.simulateBackgroundTask(.balanceRefresh)
#endif

// Test network conditions
let networkMonitor = NetworkMonitor()
networkMonitor.simulateOffline()
```

## Best Practices

1. **Always use actor isolation** for wallet operations
2. **Implement proper error handling** with user-friendly messages
3. **Test on real devices** for Keychain and biometric features
4. **Use SwiftUI previews** for rapid UI development
5. **Follow Apple's Human Interface Guidelines**
6. **Implement accessibility** features (VoiceOver, Dynamic Type)
7. **Use Combine or AsyncSequence** for reactive updates
8. **Profile performance** with Instruments
9. **Test all platform variants** your app supports
10. **Implement proper data migration** for app updates

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Local Authentication](https://developer.apple.com/documentation/localauthentication)
- [Background Tasks](https://developer.apple.com/documentation/backgroundtasks)
- [Network Framework](https://developer.apple.com/documentation/network)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)