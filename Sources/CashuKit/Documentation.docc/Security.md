# Security

Understand CashuKit's security model and best practices for secure wallet integration.

## Overview

CashuKit implements multiple layers of security for protecting user funds on Apple platforms. This document covers the security architecture, threat model, and recommendations.

## Security Features

### Keychain Storage

All sensitive data is stored in the iOS/macOS Keychain:

- **Mnemonic phrases**: Stored with biometric protection
- **Seed data**: Stored with biometric protection
- **Access tokens**: Stored per-mint
- **Queued operations**: Encrypted before storage

```swift
// Default: Maximum security with biometrics
let wallet = await AppleCashuWallet()

// Custom security configuration
let config = AppleCashuWallet.Configuration(
    enableBiometrics: true,
    enableiCloudSync: false  // Keep local only
)
```

### Biometric Authentication

CashuKit supports all Apple biometric methods:

| Platform | Method |
|----------|--------|
| iPhone | Face ID, Touch ID |
| iPad | Face ID, Touch ID |
| Mac | Touch ID |
| Vision Pro | Optic ID |

```swift
// Require biometrics for sensitive operations
try await BiometricAuthManager.shared.authenticate(
    reason: "Authenticate to send tokens"
)
```

### Secure Memory

Sensitive data is protected in memory:

- Automatic zeroization when deallocated
- No sensitive data in logs
- Constant-time comparisons for secrets

### Network Security

- All mint communication over HTTPS
- Rate limiting prevents request flooding
- Circuit breakers handle mint failures
- Offline operations queued securely

## Threat Model

### What CashuKit Protects Against

| Threat | Protection |
|--------|------------|
| Key theft | Keychain with biometric protection |
| Memory scraping | Secure memory wrappers |
| Log leakage | Automatic secret redaction |
| Network attacks | TLS, rate limiting |
| Offline attacks | Encrypted Keychain storage |

### What CashuKit Does NOT Protect Against

| Threat | Reason |
|--------|--------|
| Compromised device | If attacker has root access, all bets off |
| Malicious mint | Protocol limitation - mint can censor/inflate |
| Physical access | Side-channel attacks possible |
| Social engineering | User education required |

### Trust Model

**What we trust:**
- Apple's Keychain and Secure Enclave
- Platform CSPRNG (SecRandomCopyBytes)
- TLS certificate chain

**What we don't trust:**
- Mints (verify all signatures)
- Network (assume MITM possible)
- User input (validate everything)

## Security Recommendations

### For App Developers

1. **Enable biometric authentication**
   ```swift
   let config = AppleCashuWallet.Configuration(
       enableBiometrics: true
   )
   ```

2. **Don't disable iCloud sync carelessly**
   - Disabled by default for security
   - Enable only if user explicitly wants backup

3. **Implement proper backup flows**
   ```swift
   // Show mnemonic only after biometric auth
   try await bioManager.authenticate(reason: "Show recovery phrase")
   let mnemonic = try await wallet.getMnemonic()
   ```

4. **Handle errors securely**
   ```swift
   // Don't expose internal errors to users
   catch let error as CashuError {
       logger.error("Wallet error: \(error)") // Logged
       showUserError("Operation failed")       // Shown
   }
   ```

5. **Test on real devices**
   - Keychain behaves differently in simulator
   - Biometrics only work on real devices

### For Users

1. **Enable biometrics** when prompted
2. **Save your recovery phrase** securely (offline, not screenshot)
3. **Use trusted mints** only
4. **Keep your device updated** for security patches
5. **Don't jailbreak** devices with wallet apps

## App Store Compliance

### Required Info.plist Entries

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your Cashu wallet</string>
```

### Export Compliance

CashuKit uses encryption:
- AES for Keychain storage
- secp256k1 for signatures
- SHA256 for hashing

You may need to declare encryption usage in App Store Connect.

### Privacy Nutrition Label

Declare in your app's privacy label:
- **Financial Info**: Transaction data (stored locally)
- **Identifiers**: Device ID (if used)

## Security Audit Status

CashuKit builds on CoreCashu, which has completed security audit preparation:

- Threat model documented
- Security assumptions documented
- Static analysis completed
- No known vulnerabilities

**External security audit pending.** Use appropriate caution with significant funds until audit is complete.

## Incident Response

If you discover a security vulnerability:

1. **Do not** disclose publicly
2. Contact the maintainers privately
3. Allow time for patch development
4. Coordinate disclosure

## See Also

- <doc:Architecture>
- [CoreCashu Threat Model](https://github.com/SparrowTek/CoreCashu/blob/main/Docs/threat_model.md)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
