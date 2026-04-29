//
//  LAContextProviding.swift
//  CashuKit
//
//  Phase 8.12 follow-up (2026-04-29) — test-injectable boundary for `LAContext` so
//  ``BiometricAuthManager`` can be exercised with a fake biometric subsystem in unit tests.
//

import Foundation
import LocalAuthentication

/// A trimmed `LAContext`-like surface that ``BiometricAuthManager`` consumes. Production code
/// uses `DefaultLAContextProvider` which wraps Apple's `LAContext`; tests can supply a fake.
public protocol LAContextProviding: Sendable {
    /// Create a fresh context. The manager calls this for each availability/auth check so
    /// contexts don't leak biometric state across operations.
    func makeContext() -> any LAContextLike
}

/// Trimmed `LAContext` surface. Apple's `LAContext` already conforms via the extension below.
public protocol LAContextLike: AnyObject {
    var biometryType: LABiometryType { get }
    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool
}

extension LAContext: LAContextLike {}

/// Default provider that vends a real `LAContext` per call.
public struct DefaultLAContextProvider: LAContextProviding {
    public init() {}
    public func makeContext() -> any LAContextLike { LAContext() }
}
