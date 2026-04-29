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

    @Test("addPendingOperation persists the operation through UserDefaults round-trip")
    func addPendingOperationPersists() async {
        // Clear any leftover state from previous runs. UserDefaults is shared across the
        // process, so we have to scrub before constructing the manager.
        UserDefaults.standard.removeObject(forKey: "PendingOperations")

        let monitor = await NetworkMonitor()
        let manager = BackgroundTaskManager(networkMonitor: monitor)
        let payload = Data("test-data".utf8)

        await manager.addPendingOperation(type: "test-op", data: payload)

        // Pull straight from UserDefaults — addPendingOperation persists on every call,
        // bypassing the init-time load race that affects in-memory snapshots.
        guard let raw = UserDefaults.standard.data(forKey: "PendingOperations"),
              let decoded = try? JSONDecoder().decode([BackgroundTaskManager.PendingOperation].self, from: raw) else {
            Issue.record("expected pending operations to persist to UserDefaults")
            return
        }
        let entry = decoded.first(where: { $0.type == "test-op" })
        #expect(entry != nil)
        #expect(entry?.data == payload)

        UserDefaults.standard.removeObject(forKey: "PendingOperations")
    }
}
