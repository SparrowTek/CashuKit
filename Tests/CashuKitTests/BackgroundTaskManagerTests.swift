//
//  BackgroundTaskManagerTests.swift
//  CashuKitTests
//
//  Phase 8.12 (2026-04-29) — coverage for the testable surface of BackgroundTaskManager.
//  Full integration tests of BGTaskScheduler-driven scheduling would require an injectable
//  scheduler boundary (a public-API refactor). This suite covers the value types, error
//  shapes, and `TaskType` semantics that are directly testable today.
//

import Testing
import Foundation
@testable import CashuKit

@Suite("BackgroundTaskManager — Phase 8.12 testable surface")
struct BackgroundTaskManagerPhase812Tests {

    @Test("TaskType identifiers are unique and namespaced under com.cashukit")
    func taskTypeIdentifiers() {
        let identifiers = BackgroundTaskManager.TaskType.allCases.map(\.rawValue)
        #expect(identifiers.count == Set(identifiers).count, "task identifiers must be unique")
        for id in identifiers {
            #expect(id.hasPrefix("com.cashukit."), "task ids must be namespaced; got \(id)")
        }
    }

    @Test("TaskType minimum intervals are sensible (>= 15 minutes)")
    func taskMinimumIntervals() {
        for taskType in BackgroundTaskManager.TaskType.allCases {
            #expect(
                taskType.minimumInterval >= 15 * 60,
                "task type \(taskType.rawValue) has implausibly short minimum interval \(taskType.minimumInterval)"
            )
        }
    }

    @Test("BackgroundError supplies a non-empty description for every case")
    func backgroundErrorDescriptions() {
        let errors: [BackgroundTaskManager.BackgroundError] = [
            .taskNotRegistered,
            .taskExpired,
            .insufficientTime,
            .networkUnavailable,
            .operationFailed("simulated")
        ]
        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test("PendingOperation roundtrips through JSONEncoder/JSONDecoder")
    func pendingOperationCodable() throws {
        let payload = Data("test-payload".utf8)
        let original = BackgroundTaskManager.PendingOperation(
            type: "balance-refresh",
            data: payload,
            createdAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackgroundTaskManager.PendingOperation.self, from: encoded)

        #expect(decoded.type == original.type)
        #expect(decoded.data == original.data)
        #expect(abs(decoded.createdAt.timeIntervalSince(original.createdAt)) < 1)
    }
}
