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
}
