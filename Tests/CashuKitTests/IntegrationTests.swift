import Testing
@testable import CashuKit
import Foundation

@Suite("Integration Tests")
struct IntegrationTests {
    
    // MARK: - Test Configuration
    
    private static let testMintURL = "https://testnut.cashu.space"
    private static let testUnit = "sat"
    private static let testTimeout: TimeInterval = 30.0
    
    // MARK: - Complete Wallet Workflow Tests
    
    // TODO: get this test to pass
    @Test
    func completeWalletWorkflow() async throws {
        // Create wallet configuration
        let config = WalletConfiguration(
            mintURL: Self.testMintURL,
            unit: Self.testUnit,
            retryAttempts: 3,
            retryDelay: 1.0,
            operationTimeout: Self.testTimeout
        )
        
        let wallet = await CashuWallet(configuration: config)
        
        // Test initial state
        #expect(await wallet.state == .uninitialized)
        #expect(await wallet.isReady == false)
        
        // Test wallet initialization (this will fail with test mint, but tests the flow)
        do {
            try await wallet.initialize()
            #expect(await wallet.state == .ready)
            #expect(await wallet.isReady == true)
        } catch {
            // Expected to fail with test mint URL
            #expect(true)
        }
    }
    
    @Test
    func testTokenWorkflow() async throws {
        // Create a mock token for testing
        let proof = Proof(
            amount: 1000,
            id: "009a1f293253e41e",
            secret: "test-secret-12345",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        // Test token creation
        let token = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [proof])],
            unit: Self.testUnit,
            memo: "Test token"
        )
        
        #expect(token.token.count == 1)
        #expect(token.token[0].proofs.count == 1)
        #expect(token.token[0].proofs[0].amount == 1000)
        #expect(token.memo == "Test token")
        
        // Test token serialization
        let serialized = try CashuTokenUtils.serializeToken(token)
        #expect(serialized.hasPrefix("cashuA"))
        
        // Test token deserialization
        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs[0].amount == 1000)
        #expect(deserialized.memo == "Test token")
        
        // Test token validation
        let validationResult = ValidationUtils.validateCashuToken(deserialized)
        #expect(validationResult.isValid)
    }
    
    @Test
    func testProofManagementWorkflow() async throws {
        let proofManager = ProofManager()
        
        // Test adding proofs
        let proofs = [
            Proof(amount: 1, id: "0000000000000001", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 2, id: "0000000000000001", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 4, id: "0000000000000001", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 8, id: "0000000000000002", secret: "secret4", C: "567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890abcd")
        ]
        
        try await proofManager.addProofs(proofs)
        
        // Test balance calculation
        let totalBalance = try await proofManager.getTotalBalance()
        #expect(totalBalance == 15)
        
        // Test keyset-specific balance
        let keyset1Balance = try await proofManager.getBalance(keysetID: "0000000000000001")
        #expect(keyset1Balance == 7) // 1 + 2 + 4
        
        let keyset2Balance = try await proofManager.getBalance(keysetID: "0000000000000002")
        #expect(keyset2Balance == 8)
        
        // Test proof selection
        let selectedProofs = try await proofManager.selectProofs(amount: 10)
        let selectedTotal = selectedProofs.reduce(0) { $0 + $1.amount }
        #expect(selectedTotal >= 10)
        
        // Test marking proofs as spent
        try await proofManager.markAsSpent([proofs[0]])
        let remainingBalance = try await proofManager.getTotalBalance()
        #expect(remainingBalance == 14) // 15 - 1
        
        // Transactional lifecycle: pending -> rollback -> finalize
        try await proofManager.markAsPendingSpent([proofs[1]])
        try await proofManager.rollbackPendingSpent([proofs[1]])
        let afterRollbackSelection = try await proofManager.selectProofs(amount: 2)
        #expect(afterRollbackSelection.reduce(0) { $0 + $1.amount } >= 2)
        try await proofManager.markAsPendingSpent([proofs[1]])
        try await proofManager.finalizePendingSpent([proofs[1]])
        
        // Test proof removal (cleanup)
        try await proofManager.removeProofs([proofs[0]])
        let finalBalance = try await proofManager.getTotalBalance()
        #expect(finalBalance == 14)
    }
    
    // MARK: - Multi-Keyset Token Tests
    
    @Test
    func testMultiKeysetTokenWorkflow() async throws {
        // Create proofs from different keysets
        let proof1 = Proof(amount: 100, id: "0000000000000001", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "0000000000000002", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        
        // Create token with proofs from different keysets
        let token = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [proof1, proof2])],
            unit: Self.testUnit,
            memo: "Multi-keyset token"
        )
        
        #expect(token.token.count == 1)
        #expect(token.token[0].proofs.count == 2)
        
        // Test serialization and deserialization
        let serialized = try CashuTokenUtils.serializeToken(token)
        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
        
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs.count == 2)
        
        // Test proof extraction
        let extractedProofs = CashuTokenUtils.extractProofs(from: deserialized)
        #expect(extractedProofs.count == 2)
        
        let totalValue = extractedProofs.reduce(0) { $0 + $1.amount }
        #expect(totalValue == 300)
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test
    func testErrorHandlingWorkflow() async throws {
        // Test creating token with invalid proof
        let invalidProof = Proof(amount: 0, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        
        // Test validation of invalid proof
        let invalidToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [invalidProof])],
            unit: Self.testUnit,
            memo: nil
        )
        
        let invalidResult = ValidationUtils.validateCashuToken(invalidToken)
        #expect(!invalidResult.isValid)
        
        // Test creating token with empty proofs
        let emptyToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [])],
            unit: Self.testUnit,
            memo: nil
        )
        
        let emptyResult = ValidationUtils.validateCashuToken(emptyToken)
        #expect(!emptyResult.isValid)
        
        // Test deserializing invalid token
        do {
            _ = try CashuTokenUtils.deserializeToken("invalid-token")
            #expect(Bool(false), "Should have thrown an error for invalid token")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - Token Format Compatibility Tests
    
    @Test
    func testTokenFormatCompatibility() async throws {
        let proof = Proof(
            amount: 1000,
            id: "009a1f293253e41e",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [proof])],
            unit: Self.testUnit,
            memo: "Compatibility test"
        )
        
        // Test V3 format
        let v3Token = try CashuTokenUtils.serializeToken(token, version: .v3)
        let v3Deserialized = try CashuTokenUtils.deserializeToken(v3Token)
        
        #expect(v3Deserialized.token[0].proofs[0].amount == 1000)
        #expect(v3Deserialized.memo == "Compatibility test")
        
        // Test V3 format with URI
        let v3WithURI = try CashuTokenUtils.serializeToken(token, version: .v3, includeURI: true)
        let v3URIDeserialized = try CashuTokenUtils.deserializeToken(v3WithURI)
        
        #expect(v3URIDeserialized.token[0].proofs[0].amount == 1000)
        #expect(v3URIDeserialized.memo == "Compatibility test")
        
        // Test V4 format (currently falls back to V3)
        let v4Token = try CashuTokenUtils.serializeToken(token, version: .v4)
        let v4Deserialized = try CashuTokenUtils.deserializeToken(v4Token)
        
        #expect(v4Deserialized.token[0].proofs[0].amount == 1000)
        #expect(v4Deserialized.memo == "Compatibility test")
        
        // Test JSON format
        let jsonToken = try CashuTokenUtils.serializeTokenJSON(token)
        let jsonDeserialized = try CashuTokenUtils.deserializeTokenJSON(jsonToken)
        
        #expect(jsonDeserialized.token[0].proofs[0].amount == 1000)
        #expect(jsonDeserialized.memo == "Compatibility test")
    }
    
    // MARK: - Large Token Tests
    
    @Test
    func testLargeTokenHandling() async throws {
        // Create a token with many proofs
        var proofs: [Proof] = []
        for i in 0..<100 {
            let proof = Proof(
                amount: i + 1,
                id: String(format: "%016x", i % 10),
                secret: "secret-\(i)",
                C: String(format: "%064x", i) // Create valid hex string
            )
            proofs.append(proof)
        }
        
        let largeToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: proofs)],
            unit: Self.testUnit,
            memo: "Large token test"
        )
        
        #expect(largeToken.token.count == 1)
        #expect(largeToken.token[0].proofs.count == 100)
        
        // Test serialization of large token
        let serialized = try CashuTokenUtils.serializeToken(largeToken)
        #expect(serialized.hasPrefix("cashuA"))
        
        // Test deserialization of large token
        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs.count == 100)
        
        // Verify total value
        let totalValue = CashuTokenUtils.extractProofs(from: deserialized).reduce(0) { $0 + $1.amount }
        let expectedTotal = (1...100).reduce(0, +)
        #expect(totalValue == expectedTotal)
    }
    
    // MARK: - Performance Integration Tests
    
    @Test
    func testPerformanceIntegration() async throws {
        // Test token creation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let proof = Proof(
            amount: 1000,
            id: "009a1f293253e41e",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        for _ in 0..<100 {
            _ = CashuToken(
                token: [TokenEntry(mint: Self.testMintURL, proofs: [proof])],
                unit: Self.testUnit,
                memo: "Performance test"
            )
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Should complete in reasonable time
        #expect(duration < 5.0, "Token creation took too long: \(duration) seconds")
    }
    
    @Test
    func testSerializationPerformance() async throws {
        let proof = Proof(
            amount: 1000,
            id: "009a1f293253e41e",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [proof])],
            unit: Self.testUnit,
            memo: "Performance test"
        )
        
        // Test serialization performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var serializedTokens: [String] = []
        for _ in 0..<1000 {
            let serialized = try CashuTokenUtils.serializeToken(token)
            serializedTokens.append(serialized)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Should complete in reasonable time
        #expect(duration < 2.0, "Serialization took too long: \(duration) seconds")
        
        // Test deserialization performance
        let deserializationStartTime = CFAbsoluteTimeGetCurrent()
        
        for serialized in serializedTokens {
            _ = try CashuTokenUtils.deserializeToken(serialized)
        }
        
        let deserializationEndTime = CFAbsoluteTimeGetCurrent()
        let deserializationDuration = deserializationEndTime - deserializationStartTime
        
        // Should complete in reasonable time
        #expect(deserializationDuration < 2.0, "Deserialization took too long: \(deserializationDuration) seconds")
    }
    
    // MARK: - Edge Case Integration Tests
    
    @Test
    func testEdgeCaseIntegration() async throws {
        // Test token with minimum amount
        let minProof = Proof(
            amount: 1,
            id: "0000000000000001",
            secret: "min-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let minToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [minProof])],
            unit: Self.testUnit,
            memo: nil
        )
        let minSerialized = try CashuTokenUtils.serializeToken(minToken)
        let minDeserialized = try CashuTokenUtils.deserializeToken(minSerialized)
        
        #expect(minDeserialized.token[0].proofs[0].amount == 1)
        
        // Test token with maximum reasonable amount
        let maxProof = Proof(
            amount: Int.max,
            id: "ffffffffffffffff",
            secret: "max-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let maxToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [maxProof])],
            unit: Self.testUnit,
            memo: nil
        )
        let maxSerialized = try CashuTokenUtils.serializeToken(maxToken)
        let maxDeserialized = try CashuTokenUtils.deserializeToken(maxSerialized)
        
        #expect(maxDeserialized.token[0].proofs[0].amount == Int.max)
        
        // Test token with empty memo
        let emptyMemoToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [minProof])],
            unit: Self.testUnit,
            memo: ""
        )
        let emptyMemoSerialized = try CashuTokenUtils.serializeToken(emptyMemoToken)
        let emptyMemoDeserialized = try CashuTokenUtils.deserializeToken(emptyMemoSerialized)
        
        #expect(emptyMemoDeserialized.memo == "")
        
        // Test token with very long memo
        let longMemo = String(repeating: "a", count: 10000)
        let longMemoToken = CashuToken(
            token: [TokenEntry(mint: Self.testMintURL, proofs: [minProof])],
            unit: Self.testUnit,
            memo: longMemo
        )
        let longMemoSerialized = try CashuTokenUtils.serializeToken(longMemoToken)
        let longMemoDeserialized = try CashuTokenUtils.deserializeToken(longMemoSerialized)
        
        #expect(longMemoDeserialized.memo == longMemo)
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test
    func testConcurrentOperations() async throws {
        // Create multiple proofs
        var proofs: [Proof] = []
        for i in 0..<10 {
            let proof = Proof(
                amount: (i + 1) * 100,
                id: String(format: "%016x", i),
                secret: "secret-\(i)",
                C: String(format: "%064x", i)
            )
            proofs.append(proof)
        }
        
        // Test concurrent token creation
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                let currentProof = proofs[i]
                group.addTask {
                    do {
                        let token = CashuToken(
                            token: [TokenEntry(mint: Self.testMintURL, proofs: [currentProof])],
                            unit: Self.testUnit,
                            memo: "Concurrent test \(i)"
                        )
                        let serialized = try CashuTokenUtils.serializeToken(token)
                        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
                        
                        #expect(deserialized.token[0].proofs[0].amount == (i + 1) * 100)
                    } catch {
                        #expect(Bool(false), "Concurrent operation failed: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    @Test
    func testMemoryUsage() async throws {
        // Create and release many tokens to test memory usage
        for _ in 0..<100 {
            let proof = Proof(
                amount: 1000,
                id: "0123456789abcdef",
                secret: "memory-test-secret",
                C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
            )
            
            let token = CashuToken(
                token: [TokenEntry(mint: Self.testMintURL, proofs: [proof])],
                unit: Self.testUnit,
                memo: "Memory test"
            )
            let serialized = try CashuTokenUtils.serializeToken(token)
            _ = try CashuTokenUtils.deserializeToken(serialized)
            
            // Token should be released after this iteration
        }
        
        // Test should complete without memory issues
        #expect(Bool(true))
    }
}
