# Changelog

All notable changes to CashuKit are tracked here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it tags 1.0.

CashuKit is currently **pre-1.0** and tracks CoreCashu's roadmap. CoreCashu's own
`CHANGELOG.md` is the source of truth for protocol-level changes; this file records
CashuKit-specific deltas plus the propagation effects of CoreCashu releases.

## [Unreleased] — Tracks CoreCashu Phase 7

### Breaking

- **Inherited from CoreCashu Phase 7.1**: CoreCashu no longer re-exports `P256K`, `CryptoSwift`,
  or `BigInt` via `@_exported import`. CashuKit consumers who reach those types through
  `import CashuKit` (or `import CoreCashu`) must add the relevant package to their app's
  `Package.swift` and import it explicitly. CashuKit's own source does not use these types
  directly, so the package itself builds clean.
- **Inherited from CoreCashu Phase 7.3**: optional NUTs (P2PK / HTLC / state check / restore)
  now throw `CashuError.unsupportedOperation` when the connected mint doesn't advertise the
  capability. UI code that called these wallet methods should expect the new error case.

### Tests

- 69 Swift Testing tests pass on macOS and iOS Simulator.

## [Unreleased] — Tracks CoreCashu Phases 1–6

CashuKit's API surface did not change materially across CoreCashu Phases 1–6. The relevant
propagation effects:

- **Phase 1 — `WalletConfiguration` is `throws`**: two `WalletConfiguration` call sites in
  `Sources/CashuKit/CashuKit+Apple.swift` now `try`. Existing consumer code that constructed
  the configuration directly must add `try`.
- **Phase 2 — protocol correctness**: NUT-11 P2PK tokens issued under the pre-Phase-2 build are
  unredeemable against any real mint. Practical impact for CashuKit consumers: regenerate any
  P2PK-locked tokens stored in your app's persistence layer.
- **Phase 3 — cross-platform crypto**: no behaviour changes on Apple platforms.
- **Phase 5 — strict concurrency**: CashuKit's `Package.swift` was updated alongside CoreCashu's
  to declare `swiftLanguageModes: [.v6]` and drop the redundant `unsafeFlags`. Strict concurrency
  is now enforced in release builds too.
- **Phase 6 — testing**: in-process `MockMint` lives in the CoreCashu test target; CashuKit
  doesn't have a corresponding helper yet. Deeper unit tests for `BiometricAuthManager`,
  `BackgroundTaskManager`, `NetworkMonitor`, and `AppleWebSocketClient` are tracked as future
  work (`opus47.md` Phase 7.6 / dedicated CashuKit testing sprint).
