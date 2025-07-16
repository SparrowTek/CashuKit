//
//  NUT13Tests.swift
//  CashuKitTests
//
//  Tests for NUT-13: Deterministic Secrets
//

import Testing
@testable import CashuKit
import Foundation
import P256K

@Suite("NUT-13 Tests")
struct NUT13Tests {
    
    @Test("BIP39 mnemonic generation")
    func testMnemonicGeneration() throws {
        // Test 128-bit strength (12 words)
        let mnemonic12 = try BIP39.generateMnemonic(strength: 128)
        #expect(mnemonic12.split(separator: " ").count == 12)
        
        // Test 256-bit strength (24 words)
        let mnemonic24 = try BIP39.generateMnemonic(strength: 256)
        #expect(mnemonic24.split(separator: " ").count == 24)
        
        // Test invalid strength throws error
        #expect(throws: BIP39.BIP39Error.self) {
            _ = try BIP39.generateMnemonic(strength: 123)
        }
    }
    
    @Test("BIP39 mnemonic validation")
    func testMnemonicValidation() {
        // Valid 12-word mnemonic with correct checksum
        let validMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        #expect(BIP39.validateMnemonic(validMnemonic) == true)
        
        // Invalid word count
        let invalidCount = "abandon ability able"
        #expect(BIP39.validateMnemonic(invalidCount) == false)
        
        // Invalid word
        let invalidWord = "abandon ability able about above absent absorb abstract absurd abuse access invalid"
        #expect(BIP39.validateMnemonic(invalidWord) == false)
    }
    
    @Test("Keyset ID to integer conversion")
    func testKeysetIDToInt() throws {
        let derivation = try DeterministicSecretDerivation(masterKey: Data(repeating: 0, count: 64))
        
        // Test case from spec
        let keysetID = "009a1f293253e41e"
        let keysetInt = try derivation.keysetIDToInt(keysetID)
        
        // The expected value would be calculated as:
        // int.from_bytes(bytes.fromhex("009a1f293253e41e"), "big") % (2**31 - 1)
        #expect(keysetInt > 0)
        #expect(keysetInt < NUT13Constants.maxKeysetInt)
    }
    
    @Test("Deterministic secret derivation")
    func testSecretDerivation() async throws {
        // Test vector mnemonic
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let derivation = try DeterministicSecretDerivation(mnemonic: testMnemonic)
        
        let keysetID = "009a1f293253e41e"
        let counter: UInt32 = 0
        
        let secret = try derivation.deriveSecret(keysetID: keysetID, counter: counter)
        #expect(!secret.isEmpty)
        #expect(secret.count == 64) // 32 bytes as hex
        
        let blindingFactor = try derivation.deriveBlindingFactor(keysetID: keysetID, counter: counter)
        #expect(blindingFactor.count == 32)
    }
    
    @Test("Counter management")
    func testCounterManagement() async {
        let manager = KeysetCounterManager()
        let keysetID = "test_keyset"
        
        // Initial counter should be 0
        let initial = await manager.getCounter(for: keysetID)
        #expect(initial == 0)
        
        // Increment counter
        await manager.incrementCounter(for: keysetID)
        let afterIncrement = await manager.getCounter(for: keysetID)
        #expect(afterIncrement == 1)
        
        // Set specific value
        await manager.setCounter(for: keysetID, value: 10)
        let afterSet = await manager.getCounter(for: keysetID)
        #expect(afterSet == 10)
        
        // Reset counter
        await manager.resetCounter(for: keysetID)
        let afterReset = await manager.getCounter(for: keysetID)
        #expect(afterReset == 0)
        
        // Multiple keysets
        let keysetID2 = "another_keyset"
        await manager.setCounter(for: keysetID2, value: 5)
        let counters = await manager.getAllCounters()
        #expect(counters[keysetID] == 0)
        #expect(counters[keysetID2] == 5)
    }
    
    @Test("Wallet restoration batch generation")
    func testRestorationBatchGeneration() async throws {
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let derivation = try DeterministicSecretDerivation(mnemonic: testMnemonic)
        let counterManager = KeysetCounterManager()
        
        let restoration = WalletRestoration(
            derivation: derivation,
            counterManager: counterManager
        )
        
        let keysetID = "009a1f293253e41e"
        let startCounter: UInt32 = 0
        let batchSize = 10
        
        let batch = try await restoration.generateBlindedMessages(
            keysetID: keysetID,
            startCounter: startCounter,
            batchSize: batchSize
        )
        
        #expect(batch.count == batchSize)
        
        // Check that all blinded messages have valid B_ values
        for (blindedMessage, _) in batch {
            #expect(!blindedMessage.B_.isEmpty)
            #expect(blindedMessage.id == keysetID)
        }
    }
    
    @Test("Wallet initialization with mnemonic")
    func testWalletInitWithMnemonic() async throws {
        let mnemonic = try CashuWallet.generateMnemonic()
        
        let config = WalletConfiguration(mintURL: "https://test.mint")
        let wallet = try await CashuWallet(
            configuration: config,
            mnemonic: mnemonic
        )
        
        #expect(await wallet.supportsDeterministicSecrets == true)
    }
    
    @Test("Mnemonic validation in wallet")
    func testWalletMnemonicValidation() {
        let validMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        #expect(CashuWallet.validateMnemonic(validMnemonic) == true)
        
        let invalidMnemonic = "invalid mnemonic phrase"
        #expect(CashuWallet.validateMnemonic(invalidMnemonic) == false)
    }
    
    @Test("Deterministic path derivation")
    func testDeterministicPaths() throws {
        let derivation = try DeterministicSecretDerivation(masterKey: Data(repeating: 0, count: 64))
        
        let keysetID = "009a1f293253e41e"
        let counter: UInt32 = 5
        
        // Derive secret and blinding factor with same counter
        let secret1 = try derivation.deriveSecret(keysetID: keysetID, counter: counter)
        let secret2 = try derivation.deriveSecret(keysetID: keysetID, counter: counter)
        
        // Should be deterministic (same output for same input)
        #expect(secret1 == secret2)
        
        // Different counters should produce different secrets
        let secret3 = try derivation.deriveSecret(keysetID: keysetID, counter: counter + 1)
        #expect(secret1 != secret3)
        
        // Different keysets should produce different secrets
        let keysetID2 = "00ad268c4d1f5826"
        let secret4 = try derivation.deriveSecret(keysetID: keysetID2, counter: counter)
        #expect(secret1 != secret4)
    }
    
    @Test("Proof restoration from blinded signatures")
    func testProofRestoration() async throws {
        let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let derivation = try DeterministicSecretDerivation(mnemonic: testMnemonic)
        let counterManager = KeysetCounterManager()
        
        let restoration = WalletRestoration(
            derivation: derivation,
            counterManager: counterManager
        )
        
        let keysetID = "009a1f293253e41e"
        
        // Mock blinded signatures (in real scenario, these come from mint)
        let blindedSignatures = [
            BlindSignature(amount: 1, id: keysetID, C_: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2"),
            BlindSignature(amount: 2, id: keysetID, C_: "02a9acc1e48c25eeeb9289b5031cc57da9fe72f3fe2861d264bdc074209b107ba2")
        ]
        
        // Generate corresponding secrets and blinding factors
        var secrets: [String] = []
        var blindingFactors: [Data] = []
        
        for i in 0..<blindedSignatures.count {
            let secret = try derivation.deriveSecret(keysetID: keysetID, counter: UInt32(i))
            let r = try derivation.deriveBlindingFactor(keysetID: keysetID, counter: UInt32(i))
            
            secrets.append(secret)
            blindingFactors.append(r)
        }
        
        // Create mock mint public key for testing
        let mockPrivateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: Data(hexString: "0000000000000000000000000000000000000000000000000000000000000001")!)
        let mockPublicKey = mockPrivateKey.publicKey
        
        // Restore proofs
        let proofs = try restoration.restoreProofs(
            blindedSignatures: blindedSignatures,
            blindingFactors: blindingFactors,
            secrets: secrets,
            keysetID: keysetID,
            mintPublicKey: mockPublicKey
        )
        
        #expect(proofs.count == blindedSignatures.count)
        
        for (index, proof) in proofs.enumerated() {
            #expect(proof.amount == blindedSignatures[index].amount)
            #expect(proof.id == keysetID)
            #expect(proof.secret == secrets[index])
        }
    }
}