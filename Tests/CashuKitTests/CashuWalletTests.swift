import Testing
@testable import CashuKit
import Foundation

@Suite("Cashu Wallet Tests")
struct CashuWalletTests {
    
    // MARK: - Wallet Initialization Tests
    
    @Test
    func walletInitialization() async throws {
        let mintURL = "https://test.mint.example.com"
        let wallet = await CashuWallet(mintURL: mintURL)
        
        #expect(await wallet.state == .uninitialized)
        #expect(await wallet.isReady == false)
    }

    @Test
    func meltIdempotencyAndRollback_noLostProofsOnRetry() async throws {
        // Arrange a wallet with deterministic setup
        let config = WalletConfiguration(mintURL: "https://test.mint.example.com")
        let wallet = await CashuWallet(configuration: config)
        try? await wallet.initialize()
        if await wallet.isReady == false {
            // Environment cannot initialize (offline); skip this test
            return
        }

        // Seed wallet by importing a token that contains two proofs
        let p1 = Proof(amount: 2, id: "k1", secret: "sA", C: "cA")
        let p2 = Proof(amount: 2, id: "k1", secret: "sB", C: "cB")
        let token = CashuToken(token: [TokenEntry(mint: config.mintURL, proofs: [p1, p2])], unit: config.unit)
        _ = try await wallet.receive(token: token)

        // Attempt melt with an invalid request so execution fails after pending
        do {
            _ = try await wallet.melt(paymentRequest: "lnbc_invalid_invoice")
            #expect(Bool(false), "Expected melt to throw")
        } catch {
            // expected
        }

        // After failure, proofs must still be available (rolled back)
        let availableAfterFailure = try await wallet.selectProofsForAmount(2)
        let setAfterFailure = Set(availableAfterFailure.map { $0.secret })
        #expect(setAfterFailure.contains("sA") || setAfterFailure.contains("sB"))

        // Retry melt again (still invalid) to ensure idempotency of pending markers
        do {
            _ = try await wallet.melt(paymentRequest: "lnbc_invalid_invoice")
            #expect(Bool(false), "Expected melt to throw on retry")
        } catch { }

        let availableAfterRetry = try await wallet.selectProofsForAmount(2)
        let setAfterRetry = Set(availableAfterRetry.map { $0.secret })
        #expect(setAfterRetry.contains("sA") || setAfterRetry.contains("sB"))
    }
    // Wallet rollback semantics are validated via `IntegrationTests.testProofManagementWorkflow` and
    // service-level behaviors; wallet-level melt requires a ready mint to exercise end-to-end.
    
    @Test
    func walletConfiguration() async throws {
        let config = WalletConfiguration(
            mintURL: "https://test.mint.example.com",
            unit: "sat",
            retryAttempts: 5,
            retryDelay: 2.0,
            operationTimeout: 60.0
        )
        
        let wallet = await CashuWallet(configuration: config)
        #expect(await wallet.state == .uninitialized)
    }
    
    // MARK: - Token Import/Export Tests
    
    @Test
    func tokenExportImport() async throws {
        // Create a mock token directly instead of using wallet
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://test.mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test token"
        )
        
        // Test serialization
        let serialized = try CashuTokenUtils.serializeToken(token)
        #expect(!serialized.isEmpty)
        #expect(serialized.hasPrefix("cashuA"))
        
        // Test deserialization
        let deserialized = try CashuTokenUtils.deserializeToken(serialized)
        #expect(deserialized.token.count == 1)
        #expect(deserialized.token[0].proofs.count == 1)
        #expect(deserialized.token[0].proofs[0].amount == 100)
        #expect(deserialized.memo == "Test token")
    }
    
    @Test
    func tokenValidation() async throws {
        // Valid token
        let validProof = Proof(
            amount: 100,
            id: "valid-id",
            secret: "valid-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let validToken = CashuToken(
            token: [TokenEntry(mint: "https://test.mint.example.com", proofs: [validProof])],
            unit: "sat",
            memo: nil
        )
        
        let validResult = ValidationUtils.validateCashuToken(validToken)
        #expect(validResult.isValid)
        
        // Invalid token - empty proofs
        let invalidToken = CashuToken(
            token: [TokenEntry(mint: "https://test.mint.example.com", proofs: [])],
            unit: "sat",
            memo: nil
        )
        
        let invalidResult = ValidationUtils.validateCashuToken(invalidToken)
        #expect(!invalidResult.isValid)
        #expect(invalidResult.errors.contains { $0.contains("Proof array cannot be empty") })
    }
    
    // MARK: - Proof Management Tests
    
    @Test
    func proofStorage() async throws {
        let storage = InMemoryProofStorage()
        let proofs = [
            Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        ]
        
        try await storage.store(proofs)
        
        let retrievedProofs = try await storage.retrieveAll()
        #expect(retrievedProofs.count == 2)
        
        let count = try await storage.count()
        #expect(count == 2)
        
        let containsFirst = try await storage.contains(proofs[0])
        #expect(containsFirst)
        
        try await storage.remove([proofs[0]])
        let remainingProofs = try await storage.retrieveAll()
        #expect(remainingProofs.count == 1)
    }
    
    @Test
    func proofManager() async throws {
        let proofManager = ProofManager()
        
        let proofs = [
            Proof(amount: 100, id: "keyset1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 200, id: "keyset1", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 50, id: "keyset2", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        ]
        
        try await proofManager.addProofs(proofs)
        
        let totalBalance = try await proofManager.getTotalBalance()
        #expect(totalBalance == 350)
        
        let keyset1Balance = try await proofManager.getBalance(keysetID: "keyset1")
        #expect(keyset1Balance == 300)
        
        let keyset2Balance = try await proofManager.getBalance(keysetID: "keyset2")
        #expect(keyset2Balance == 50)
        
        let selectedProofs = try await proofManager.selectProofs(amount: 150)
        let selectedTotal = selectedProofs.reduce(0) { $0 + $1.amount }
        #expect(selectedTotal >= 150)
    }
    
    // MARK: - Balance Calculation Tests
    
    @Test
    func balanceCalculation() async throws {
        let proofManager = ProofManager()
        
        let proofs = [
            Proof(amount: 1, id: "keyset1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 2, id: "keyset1", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 4, id: "keyset1", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 8, id: "keyset1", secret: "secret4", C: "567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890abcd")
        ]
        
        try await proofManager.addProofs(proofs)
        
        let totalBalance = try await proofManager.getTotalBalance()
        #expect(totalBalance == 15)
        
        // Test marking proofs as spent
        try await proofManager.markAsSpent([proofs[0], proofs[1]])
        let remainingBalance = try await proofManager.getTotalBalance()
        #expect(remainingBalance == 12) // 15 - 1 - 2
    }
    
    // MARK: - Denomination Handling Tests
    
    @Test
    func denominationHandling() async throws {
        let proofManager = ProofManager()
        
        // Test with standard Bitcoin denominations
        let proofs = [
            Proof(amount: 1, id: "keyset1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 2, id: "keyset1", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 4, id: "keyset1", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 8, id: "keyset1", secret: "secret4", C: "567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890abcd"),
            Proof(amount: 16, id: "keyset1", secret: "secret5", C: "90abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890abcdef12")
        ]
        
        try await proofManager.addProofs(proofs)
        
        // Test optimal selection for various amounts
        let selectedFor5 = try await proofManager.selectProofs(amount: 5)
        let totalFor5 = selectedFor5.reduce(0) { $0 + $1.amount }
        #expect(totalFor5 >= 5)
        
        let selectedFor10 = try await proofManager.selectProofs(amount: 10)
        let totalFor10 = selectedFor10.reduce(0) { $0 + $1.amount }
        #expect(totalFor10 >= 10)
        
        let selectedFor15 = try await proofManager.selectProofs(amount: 15)
        let totalFor15 = selectedFor15.reduce(0) { $0 + $1.amount }
        #expect(totalFor15 >= 15)
    }
    
    // MARK: - Token Serialization Format Tests
    
    @Test
    func tokenSerializationFormats() async throws {
        let proof = Proof(
            amount: 100,
            id: "test-keyset-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://test.mint.example.com", proofs: [proof])],
            unit: "sat",
            memo: "Test memo"
        )
        
        // Test V3 format
        let v3Token = try CashuTokenUtils.serializeToken(token, version: .v3)
        #expect(v3Token.hasPrefix("cashuA"))
        
        let v3Deserialized = try CashuTokenUtils.deserializeToken(v3Token)
        #expect(v3Deserialized.token[0].proofs[0].amount == 100)
        #expect(v3Deserialized.memo == "Test memo")
        
        // Test with URI
        let v3WithURI = try CashuTokenUtils.serializeToken(token, version: .v3, includeURI: true)
        #expect(v3WithURI.hasPrefix("cashu:cashuA"))
        
        let v3URIDeserialized = try CashuTokenUtils.deserializeToken(v3WithURI)
        #expect(v3URIDeserialized.token[0].proofs[0].amount == 100)
        
        // Test JSON format
        let jsonToken = try CashuTokenUtils.serializeTokenJSON(token)
        let jsonDeserialized = try CashuTokenUtils.deserializeTokenJSON(jsonToken)
        #expect(jsonDeserialized.token[0].proofs[0].amount == 100)
    }
    
    // MARK: - Proof Collection Extension Tests
    
    @Test
    func proofCollectionExtensions() async throws {
        let proofs = [
            Proof(amount: 100, id: "keyset1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 200, id: "keyset1", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 50, id: "keyset2", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        ]
        
        // Test total value
        let totalValue = proofs.totalValue
        #expect(totalValue == 350)
        
        // Test filtering by keyset
        let keyset1Proofs = proofs.proofs(for: "keyset1")
        #expect(keyset1Proofs.count == 2)
        #expect(keyset1Proofs.totalValue == 300)
        
        // Test grouping by keyset
        let groupedProofs = proofs.groupedByKeyset()
        #expect(groupedProofs.count == 2)
        #expect(groupedProofs["keyset1"]?.count == 2)
        #expect(groupedProofs["keyset2"]?.count == 1)
        
        // Test unique keyset IDs
        let keysetIDs = proofs.keysetIDs
        #expect(keysetIDs.count == 2)
        #expect(keysetIDs.contains("keyset1"))
        #expect(keysetIDs.contains("keyset2"))
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func proofValidationErrors() async throws {
        let proofManager = ProofManager()
        
        // Test invalid amount
        let invalidAmountProof = Proof(amount: 0, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        
        do {
            try await proofManager.addProofs([invalidAmountProof])
            #expect(Bool(false), "Should have thrown an error for invalid amount")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test empty secret
        let emptySecretProof = Proof(amount: 100, id: "id", secret: "", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        
        do {
            try await proofManager.addProofs([emptySecretProof])
            #expect(Bool(false), "Should have thrown an error for empty secret")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test invalid hex string
        let invalidHexProof = Proof(amount: 100, id: "id", secret: "secret", C: "invalid-hex")
        
        do {
            try await proofManager.addProofs([invalidHexProof])
            #expect(Bool(false), "Should have thrown an error for invalid hex")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test
    func insufficientBalanceError() async throws {
        let proofManager = ProofManager()
        
        let proof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        try await proofManager.addProofs([proof])
        
        do {
            _ = try await proofManager.selectProofs(amount: 200)
            #expect(Bool(false), "Should have thrown an error for insufficient balance")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test
    func noSpendableProofsError() async throws {
        let proofManager = ProofManager()
        
        do {
            _ = try await proofManager.selectProofs(amount: 100)
            #expect(Bool(false), "Should have thrown an error for no spendable proofs")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - Denomination Utils Tests
    
    @Test
    func denominationUtilsOptimalBreakdown() async throws {
        // Test standard amounts
        let breakdown100 = DenominationUtils.getOptimalDenominations(amount: 100)
        #expect(breakdown100[64] == 1)
        #expect(breakdown100[32] == 1)
        #expect(breakdown100[4] == 1)
        
        let breakdown255 = DenominationUtils.getOptimalDenominations(amount: 255)
        #expect(breakdown255[128] == 1)
        #expect(breakdown255[64] == 1)
        #expect(breakdown255[32] == 1)
        #expect(breakdown255[16] == 1)
        #expect(breakdown255[8] == 1)
        #expect(breakdown255[4] == 1)
        #expect(breakdown255[2] == 1)
        #expect(breakdown255[1] == 1)
        
        // Test edge cases
        let breakdown0 = DenominationUtils.getOptimalDenominations(amount: 0)
        #expect(breakdown0.isEmpty)
        
        let breakdown1 = DenominationUtils.getOptimalDenominations(amount: 1)
        #expect(breakdown1[1] == 1)
        #expect(breakdown1.count == 1)
    }
    
    @Test
    func denominationUtilsEfficiency() async throws {
        // Optimal breakdown (powers of 2)
        let optimal: [Int: Int] = [1: 1, 2: 1, 4: 1, 8: 1] // Total: 15, 4 proofs
        let optimalEfficiency = DenominationUtils.calculateEfficiency(optimal)
        #expect(optimalEfficiency == 1.0)
        
        // Suboptimal breakdown (all 1s)
        let suboptimal: [Int: Int] = [1: 15] // Total: 15, 15 proofs
        let suboptimalEfficiency = DenominationUtils.calculateEfficiency(suboptimal)
        #expect(suboptimalEfficiency < 1.0)
        #expect(suboptimalEfficiency > 0.0)
        
        // Test efficiency check
        #expect(DenominationUtils.isEfficient(optimal, threshold: 0.8))
        #expect(!DenominationUtils.isEfficient(suboptimal, threshold: 0.8))
    }
    
    @Test
    func proofDenominationCounts() async throws {
        let proofs = [
            Proof(amount: 1, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 1, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 2, id: "id3", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 4, id: "id4", secret: "secret4", C: "567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890abcd"),
            Proof(amount: 4, id: "id5", secret: "secret5", C: "90abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890abcdef12")
        ]
        
        let denominationCounts = proofs.denominationCounts
        #expect(denominationCounts[1] == 2)
        #expect(denominationCounts[2] == 1)
        #expect(denominationCounts[4] == 2)
        #expect(denominationCounts.count == 3)
    }
    
    // MARK: - Balance Breakdown Tests
    
    @Test
    func balanceBreakdownTypes() async throws {
        // Test BalanceBreakdown
        let keysetBalance1 = KeysetBalance(
            keysetID: "keyset1",
            balance: 300,
            proofCount: 3,
            denominations: [1: 1, 2: 1, 4: 1],
            isActive: true
        )
        
        let keysetBalance2 = KeysetBalance(
            keysetID: "keyset2",
            balance: 50,
            proofCount: 1,
            denominations: [50: 1],
            isActive: false
        )
        
        let balanceBreakdown = BalanceBreakdown(
            totalBalance: 350,
            keysetBalances: ["keyset1": keysetBalance1, "keyset2": keysetBalance2],
            proofCount: 4
        )
        
        #expect(balanceBreakdown.totalBalance == 350)
        #expect(balanceBreakdown.keysetBalances.count == 2)
        #expect(balanceBreakdown.proofCount == 4)
        #expect(balanceBreakdown.keysetBalances["keyset1"]?.isActive == true)
        #expect(balanceBreakdown.keysetBalances["keyset2"]?.isActive == false)
    }
    
    @Test
    func balanceUpdateTypes() async throws {
        let update = BalanceUpdate(
            newBalance: 200,
            previousBalance: 100,
            timestamp: Date()
        )
        
        #expect(update.balanceChanged == true)
        #expect(update.balanceDifference == 100)
        #expect(update.error == nil)
        
        let noChangeUpdate = BalanceUpdate(
            newBalance: 100,
            previousBalance: 100,
            timestamp: Date()
        )
        
        #expect(noChangeUpdate.balanceChanged == false)
        #expect(noChangeUpdate.balanceDifference == 0)
    }
    
    @Test
    func denominationBreakdownTypes() async throws {
        let denominations: [Int: Int] = [1: 5, 2: 3, 4: 2, 8: 1]
        let breakdown = DenominationBreakdown(
            denominations: denominations,
            totalValue: 25, // 5*1 + 3*2 + 2*4 + 1*8
            totalProofs: 11 // 5 + 3 + 2 + 1
        )
        
        #expect(breakdown.totalValue == 25)
        #expect(breakdown.totalProofs == 11)
        #expect(breakdown.availableDenominations == [1, 2, 4, 8])
        #expect(breakdown.denominations[1] == 5)
        #expect(breakdown.denominations[8] == 1)
    }
    
    @Test
    func optimizationResultTypes() async throws {
        let previousDenominations: [Int: Int] = [1: 15]
        let newDenominations: [Int: Int] = [1: 1, 2: 1, 4: 1, 8: 1]
        
        let result = OptimizationResult(
            success: true,
            proofsChanged: true,
            newProofs: [],
            previousDenominations: previousDenominations,
            newDenominations: newDenominations
        )
        
        #expect(result.success == true)
        #expect(result.proofsChanged == true)
        #expect(result.newProofs.isEmpty)
        #expect(result.previousDenominations[1] == 15)
        #expect(result.newDenominations[8] == 1)
    }
    
    // MARK: - Integration Tests for New Functionality
    
    @Test
    func walletStatisticsIntegration() async throws {
        let proofManager = ProofManager()
        
        let proofs = [
            Proof(amount: 100, id: "keyset1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 200, id: "keyset1", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 50, id: "keyset2", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        ]
        
        try await proofManager.addProofs(proofs)
        
        // Test that the ProofManager correctly tracks balances by keyset
        let totalBalance = try await proofManager.getTotalBalance()
        let keyset1Balance = try await proofManager.getBalance(keysetID: "keyset1")
        let keyset2Balance = try await proofManager.getBalance(keysetID: "keyset2")
        
        #expect(totalBalance == 350)
        #expect(keyset1Balance == 300)
        #expect(keyset2Balance == 50)
        
        // Test proof selection optimization
        let selectedForSmallAmount = try await proofManager.selectProofs(amount: 50)
        #expect(selectedForSmallAmount.count == 1) // Should select the 50 sat proof
        #expect(selectedForSmallAmount[0].amount == 50)
        
        // Test proof selection for larger amount
        let selectedForLargeAmount = try await proofManager.selectProofs(amount: 250)
        let selectedTotal = selectedForLargeAmount.reduce(0) { $0 + $1.amount }
        #expect(selectedTotal >= 250)
        #expect(selectedTotal <= 350) // Maximum possible with available proofs
    }
    
    @Test
    func tokenUtilsIntegrationWithNewFeatures() async throws {
        let proof1 = Proof(amount: 100, id: "keyset1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let proof2 = Proof(amount: 200, id: "keyset1", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        let proof3 = Proof(amount: 50, id: "keyset2", secret: "secret3", C: "1234567890abcdefdeadbeef1234567890abcdef1234567890abcdef1234567890")
        
        let entry1 = TokenEntry(mint: "https://mint1.example.com", proofs: [proof1, proof2])
        let entry2 = TokenEntry(mint: "https://mint2.example.com", proofs: [proof3])
        
        let token = CashuToken(token: [entry1, entry2], unit: "sat", memo: "Test multi-mint token")
        
        // Test value calculation
        let totalValue = CashuTokenUtils.calculateTokenValue(token)
        #expect(totalValue == 350)
        
        // Test grouping by mint
        let groupedProofs = CashuTokenUtils.groupProofsByMint(token)
        #expect(groupedProofs.count == 2)
        #expect(groupedProofs["https://mint1.example.com"]?.count == 2)
        #expect(groupedProofs["https://mint2.example.com"]?.count == 1)
        
        // Test import validation
        let validationResult = CashuTokenUtils.validateImportedToken(token)
        #expect(validationResult.isValid)
        #expect(validationResult.totalValue == 350)
        #expect(validationResult.errors.isEmpty)
        
        // Test export/import round trip
        let exported = try CashuTokenUtils.exportToken(token, format: .serialized)
        let imported = try CashuTokenUtils.importToken(exported)
        
        #expect(imported.token.count == 2)
        #expect(CashuTokenUtils.calculateTokenValue(imported) == 350)
        #expect(imported.memo == "Test multi-mint token")
    }
}
