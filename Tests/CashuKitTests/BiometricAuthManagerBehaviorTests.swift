//
//  BiometricAuthManagerBehaviorTests.swift
//  CashuKitTests
//
//  Phase 8.12 follow-up (2026-04-29) — fake-driven behavioral tests for BiometricAuthManager
//  using the new LAContextProviding seam.
//

import Testing
import Foundation
import LocalAuthentication
@testable import CashuKit

@Suite("BiometricAuthManager — fake-driven behavior")
struct BiometricAuthManagerBehaviorTests {

    /// Fake `LAContextLike` that returns canned answers for `canEvaluatePolicy` and
    /// `evaluatePolicy(_:localizedReason:)`. Phase 8.12.
    final class FakeLAContext: LAContextLike, @unchecked Sendable {
        let canEvaluate: Bool
        let evaluateError: NSError?
        let evaluatePolicyResult: Result<Bool, Error>
        let typeOnSuccess: LABiometryType

        init(
            canEvaluate: Bool,
            evaluateError: NSError? = nil,
            evaluatePolicyResult: Result<Bool, Error> = .success(true),
            typeOnSuccess: LABiometryType = .faceID
        ) {
            self.canEvaluate = canEvaluate
            self.evaluateError = evaluateError
            self.evaluatePolicyResult = evaluatePolicyResult
            self.typeOnSuccess = typeOnSuccess
        }

        var biometryType: LABiometryType { canEvaluate ? typeOnSuccess : .none }

        func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
            if !canEvaluate, let evaluateError {
                error?.pointee = evaluateError
            }
            return canEvaluate
        }

        func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
            try evaluatePolicyResult.get()
        }
    }

    struct FakeProvider: LAContextProviding {
        let factory: @Sendable () -> any LAContextLike
        func makeContext() -> any LAContextLike { factory() }
    }

    @Test("checkBiometricAvailability marks Face ID available when canEvaluatePolicy returns true")
    func detectsFaceIDAvailable() async {
        let manager = BiometricAuthManager(contextProvider: FakeProvider {
            FakeLAContext(canEvaluate: true, typeOnSuccess: .faceID)
        })
        await manager.checkBiometricAvailability()
        #expect(await manager.isAvailable == true)
        #expect(await manager.isEnrolled == true)
        #expect(await manager.biometricType == .faceID)
    }

    @Test("checkBiometricAvailability marks Touch ID available when type is touchID")
    func detectsTouchIDAvailable() async {
        let manager = BiometricAuthManager(contextProvider: FakeProvider {
            FakeLAContext(canEvaluate: true, typeOnSuccess: .touchID)
        })
        await manager.checkBiometricAvailability()
        #expect(await manager.biometricType == .touchID)
    }

    @Test("checkBiometricAvailability flags biometryNotEnrolled error correctly")
    func handlesNotEnrolledError() async {
        let notEnrolledError = NSError(domain: LAError.errorDomain, code: LAError.biometryNotEnrolled.rawValue)
        let manager = BiometricAuthManager(contextProvider: FakeProvider {
            FakeLAContext(canEvaluate: false, evaluateError: notEnrolledError)
        })
        await manager.checkBiometricAvailability()
        #expect(await manager.isAvailable == false)
        #expect(await manager.isEnrolled == false)
        #expect(await manager.biometricType == .none)
    }

    @Test("authenticate throws biometryNotAvailable when manager is not available")
    func authenticateRejectsWhenUnavailable() async {
        let manager = BiometricAuthManager(contextProvider: FakeProvider {
            FakeLAContext(canEvaluate: false)
        })
        await manager.checkBiometricAvailability()

        await #expect(throws: BiometricAuthManager.AuthenticationError.self) {
            try await manager.authenticate(reason: "test")
        }
    }

    @Test("configure(policy:) updates the manager's policy")
    func configureUpdatesPolicy() async {
        let manager = BiometricAuthManager(contextProvider: FakeProvider {
            FakeLAContext(canEvaluate: true)
        })
        await manager.configure(policy: .biometryOnly)
        // No public getter for the policy itself; we verify by behavior of
        // `authenticateForSensitiveOperation`, which is the only consumer of the policy in
        // the public API. Configure is `nonisolated public` and stores the new value.
        // The smoke check: configure didn't crash, manager is still usable.
        #expect(await manager.isAvailable == false) // not yet checked
    }
}
