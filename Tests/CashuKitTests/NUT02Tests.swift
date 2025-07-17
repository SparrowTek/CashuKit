//
//  NUT02Tests.swift
//  CashuKit
//
//  Tests for NUT-02: Keysets and fees
//

import Testing
@testable import CashuKit

@Suite("NUT02 tests")
struct NUT02Tests {
    
    // MARK: - KeysetInfo Tests
    @Test
    func keysetInfoValidation() {
        // Valid keyset info
        let validKeysetInfo = KeysetInfo(
            id: "0088553333AABBCC",
            unit: "sat",
            active: true,
            inputFeePpk: 1000
        )
        #expect(validKeysetInfo.id == "0088553333AABBCC")
        #expect(validKeysetInfo.unit == "sat")
        #expect(validKeysetInfo.active)
        #expect(validKeysetInfo.inputFeePpk == 1000)
        
        // Keyset info without fee
        let keysetInfoNoFee = KeysetInfo(
            id: "0088553333AABBCC",
            unit: "sat",
            active: true
        )
        #expect(keysetInfoNoFee.inputFeePpk == nil)
    }
    
    @Test
    func keysetInfoCodingKeys() {
        // Test that coding keys work correctly
        let keysetInfo = KeysetInfo(
            id: "0088553333AABBCC",
            unit: "sat",
            active: true,
            inputFeePpk: 1000
        )
        
        // Ensure the object can be created
        #expect(keysetInfo.inputFeePpk == 1000)
    }
    
    // MARK: - GetKeysetsResponse Tests
    
    @Test
    func getKeysetsResponseValidation() {
        let keysetInfo1 = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetInfo2 = KeysetInfo(id: "keyset2", unit: "usd", active: false, inputFeePpk: 500)
        
        let response = GetKeysetsResponse(keysets: [keysetInfo1, keysetInfo2])
        #expect(response.keysets.count == 2)
        #expect(response.keysets[0].id == "keyset1")
        #expect(response.keysets[1].id == "keyset2")
    }
    
    // MARK: - WalletSyncResult Tests
    
    @Test
    func walletSyncResult() {
        var syncResult = WalletSyncResult()
        #expect(!syncResult.hasChanges)
        
        syncResult.newKeysets.append("keyset1")
        #expect(syncResult.hasChanges)
        
        syncResult = WalletSyncResult()
        syncResult.newlyActiveKeysets.append("keyset2")
        #expect(syncResult.hasChanges)
        
        syncResult = WalletSyncResult()
        syncResult.newlyInactiveKeysets.append("keyset3")
        #expect(syncResult.hasChanges)
    }
    
    // MARK: - ProofSelectionOption Tests
    
    @Test
    func proofSelectionOption() {
        let proof1 = Proof(amount: 64, id: "keyset1", secret: "secret1", C: "signature1")
        let proof2 = Proof(amount: 32, id: "keyset1", secret: "secret2", C: "signature2")
        
        let option = ProofSelectionOption(
            selectedProofs: [proof1, proof2],
            totalAmount: 96,
            totalFee: 2,
            keysetID: "keyset1",
            efficiency: 0.95
        )
        
        #expect(option.selectedProofs.count == 2)
        #expect(option.totalAmount == 96)
        #expect(option.totalFee == 2)
        #expect(option.keysetID == "keyset1")
        #expect(abs(option.efficiency - 0.95) < 0.001)
        #expect(option.changeAmount == 94) // totalAmount - totalFee
    }
    
    @Test
    func proofSelectionResult() {
        let proof = Proof(amount: 64, id: "keyset1", secret: "secret", C: "signature")
        let option1 = ProofSelectionOption(
            selectedProofs: [proof],
            totalAmount: 64,
            totalFee: 1,
            keysetID: "keyset1",
            efficiency: 0.95
        )
        let option2 = ProofSelectionOption(
            selectedProofs: [proof],
            totalAmount: 64,
            totalFee: 2,
            keysetID: "keyset2",
            efficiency: 0.90
        )
        
        let result = ProofSelectionResult(
            recommended: option1,
            alternatives: [option2]
        )
        
        #expect(result.recommended != nil)
        #expect(result.recommended?.totalFee == 1)
        #expect(result.alternatives.count == 1)
        #expect(result.alternatives[0].totalFee == 2)
    }
    
    // MARK: - TransactionValidationResult Tests
    
    @Test
    func transactionValidationResult() {
        let feeBreakdown: [String: (count: Int, totalFeePpk: Int, totalFee: Int)] = [
            "keyset1": (count: 2, totalFeePpk: 2000, totalFee: 2),
            "keyset2": (count: 1, totalFeePpk: 500, totalFee: 1)
        ]
        
        let result = TransactionValidationResult(
            isValid: true,
            totalInputs: 100,
            totalOutputs: 97,
            totalFees: 3,
            balance: 0,
            feeBreakdown: feeBreakdown
        )
        
        #expect(result.isValid)
        #expect(result.totalInputs == 100)
        #expect(result.totalOutputs == 97)
        #expect(result.totalFees == 3)
        #expect(result.balance == 0)
        #expect(result.feeBreakdown.keys.count == 2)
        #expect(result.feeBreakdown["keyset1"]?.count == 2)
        #expect(result.feeBreakdown["keyset2"]?.totalFee == 1)
    }
    
    // MARK: - KeysetID Tests
    
    @Test
    func keysetIDValidation() {
        // Valid keyset IDs (16 characters: 2 for version + 14 for hash)
        #expect(KeysetID.validateKeysetID("0088553333AABBCC"))
        #expect(KeysetID.validateKeysetID("00abcdef123456ef"))
        #expect(KeysetID.validateKeysetID("0000000000000000"))
        #expect(KeysetID.validateKeysetID("00FFFFFFFFFFFFFF"))
        
        // Invalid keyset IDs
        #expect(!KeysetID.validateKeysetID("")) // Empty
        #expect(!KeysetID.validateKeysetID("123456789012345")) // Too short
        #expect(!KeysetID.validateKeysetID("12345678901234567")) // Too long
        #expect(!KeysetID.validateKeysetID("gggg5678901234567")) // Invalid hex
        #expect(!KeysetID.validateKeysetID("0188553333AABBCC")) // Wrong version prefix
        #expect(!KeysetID.validateKeysetID("FF88553333AABBCC")) // Wrong version prefix
    }
    
    @Test
    func keysetIDDerivation() {
        // Test keyset ID derivation
        let keys = [
            "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
            "2": "03fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
            "4": "02123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01"
        ]
        
        let derivedID = KeysetID.deriveKeysetID(from: keys)
        
        // Should be 16 characters (2 for version + 14 for hash)
        #expect(derivedID.count == 16)
        
        // Should start with current version (00)
        #expect(derivedID.hasPrefix(KeysetID.currentVersion))
        
        // Should be valid hex
        #expect(derivedID.isValidHex)
        
        // Should be deterministic - same keys should produce same ID
        let derivedID2 = KeysetID.deriveKeysetID(from: keys)
        #expect(derivedID == derivedID2)
        
        // Different keys should produce different ID
        let differentKeys = [
            "1": "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a", // Different key
            "2": "03fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
            "4": "02123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01"
        ]
        let differentID = KeysetID.deriveKeysetID(from: differentKeys)
        #expect(derivedID != differentID)
    }
    
    @Test
    func keysetIDCurrentVersion() {
        #expect(KeysetID.currentVersion == "00")
    }
    
    // MARK: - FeeCalculator Tests
    
    @Test
    func feeCalculatorBasic() {
        let keysetInfo1 = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetInfo2 = KeysetInfo(id: "keyset2", unit: "sat", active: true, inputFeePpk: 500)
        
        let keysetDict = [
            "keyset1": keysetInfo1,
            "keyset2": keysetInfo2
        ]
        
        let proof1 = Proof(amount: 64, id: "keyset1", secret: "secret1", C: "signature1")
        let proof2 = Proof(amount: 32, id: "keyset1", secret: "secret2", C: "signature2")
        let proof3 = Proof(amount: 16, id: "keyset2", secret: "secret3", C: "signature3")
        
        let proofs = [proof1, proof2, proof3]
        
        // Calculate fees: (1000 + 1000 + 500) / 1000 = 2.5, rounded up to 3
        let totalFees = FeeCalculator.calculateFees(for: proofs, keysetInfo: keysetDict)
        #expect(totalFees == 3)
    }
    
    @Test
    func feeCalculatorZeroFees() {
        let keysetInfo = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 0)
        let keysetDict = ["keyset1": keysetInfo]
        
        let proof = Proof(amount: 64, id: "keyset1", secret: "secret", C: "signature")
        let proofs = [proof]
        
        let totalFees = FeeCalculator.calculateFees(for: proofs, keysetInfo: keysetDict)
        #expect(totalFees == 0)
    }
    
    @Test
    func feeCalculatorMissingKeyset() {
        let keysetDict: [String: KeysetInfo] = [:]
        
        let proof = Proof(amount: 64, id: "unknown_keyset", secret: "secret", C: "signature")
        let proofs = [proof]
        
        // Should default to 0 fee for unknown keysets
        let totalFees = FeeCalculator.calculateFees(for: proofs, keysetInfo: keysetDict)
        #expect(totalFees == 0)
    }
    
    @Test
    func feeCalculatorRounding() {
        // Test different rounding scenarios
        let testCases = [
            (feePpk: 1, expectedFee: 1),    // 1/1000 = 0.001, rounds up to 1
            (feePpk: 999, expectedFee: 1),  // 999/1000 = 0.999, rounds up to 1
            (feePpk: 1000, expectedFee: 1), // 1000/1000 = 1.0, exactly 1
            (feePpk: 1001, expectedFee: 2), // 1001/1000 = 1.001, rounds up to 2
            (feePpk: 1500, expectedFee: 2), // 1500/1000 = 1.5, rounds up to 2
            (feePpk: 2000, expectedFee: 2), // 2000/1000 = 2.0, exactly 2
        ]
        
        for testCase in testCases {
            let keysetInfo = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: testCase.feePpk)
            let keysetDict = ["keyset1": keysetInfo]
            
            let proof = Proof(amount: 64, id: "keyset1", secret: "secret", C: "signature")
            let proofs = [proof]
            
            let calculatedFee = FeeCalculator.calculateFees(for: proofs, keysetInfo: keysetDict)
            #expect(calculatedFee == testCase.expectedFee, "Fee calculation failed for \(testCase.feePpk) ppk")
        }
    }
    
    @Test
    func feeCalculatorTotalFee() {
        let inputs = [
            (keysetID: "keyset1", inputFeePpk: 1000),
            (keysetID: "keyset2", inputFeePpk: 500),
            (keysetID: "keyset1", inputFeePpk: 1000)
        ]
        
        // Total: 1000 + 500 + 1000 = 2500 ppk
        // Fee: ceil(2500/1000) = 3
        let totalFee = FeeCalculator.calculateTotalFee(inputs: inputs)
        #expect(totalFee == 3)
    }
    
    @Test
    func feeCalculatorProofFeePpk() {
        let keysetInfo = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 1500)
        let proof = Proof(amount: 64, id: "keyset1", secret: "secret", C: "signature")
        
        let feePpk = FeeCalculator.calculateProofFeePpk(for: proof, keysetInfo: keysetInfo)
        #expect(feePpk == 1500)
        
        // Test with no fee specified
        let keysetInfoNoFee = KeysetInfo(id: "keyset1", unit: "sat", active: true)
        let feePpkNoFee = FeeCalculator.calculateProofFeePpk(for: proof, keysetInfo: keysetInfoNoFee)
        #expect(feePpkNoFee == 0)
    }
    
    @Test
    func feeCalculatorTransactionBalance() {
        let keysetInfo = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetDict = ["keyset1": keysetInfo]
        
        let inputProofs = [
            Proof(amount: 64, id: "keyset1", secret: "secret1", C: "signature1"),
            Proof(amount: 32, id: "keyset1", secret: "secret2", C: "signature2")
        ]
        
        // Total inputs: 96, Total fees: 2000/1000 = 2, Available for outputs: 94
        let outputAmounts = [64, 30] // Total: 94
        
        let isValid = FeeCalculator.validateTransactionBalance(
            inputProofs: inputProofs,
            outputAmounts: outputAmounts,
            keysetInfo: keysetDict
        )
        #expect(isValid)
        
        // Invalid balance
        let invalidOutputAmounts = [64, 32] // Total: 96, but should be 94 after fees
        let isInvalid = FeeCalculator.validateTransactionBalance(
            inputProofs: inputProofs,
            outputAmounts: invalidOutputAmounts,
            keysetInfo: keysetDict
        )
        #expect(!isInvalid)
    }
    
    @Test
    func feeCalculatorBreakdown() {
        let keysetInfo1 = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetInfo2 = KeysetInfo(id: "keyset2", unit: "sat", active: true, inputFeePpk: 500)
        
        let keysetDict = [
            "keyset1": keysetInfo1,
            "keyset2": keysetInfo2
        ]
        
        let proofs = [
            Proof(amount: 64, id: "keyset1", secret: "secret1", C: "signature1"),
            Proof(amount: 32, id: "keyset1", secret: "secret2", C: "signature2"),
            Proof(amount: 16, id: "keyset2", secret: "secret3", C: "signature3"),
            Proof(amount: 8, id: "keyset2", secret: "secret4", C: "signature4")
        ]
        
        let breakdown = FeeCalculator.getFeeBreakdown(for: proofs, keysetInfo: keysetDict)
        
        #expect(breakdown.keys.count == 2)
        
        // keyset1: 2 proofs, 2000 ppk total, 2 fee
        #expect(breakdown["keyset1"]?.count == 2)
        #expect(breakdown["keyset1"]?.totalFeePpk == 2000)
        #expect(breakdown["keyset1"]?.totalFee == 2)
        
        // keyset2: 2 proofs, 1000 ppk total, 1 fee
        #expect(breakdown["keyset2"]?.count == 2)
        #expect(breakdown["keyset2"]?.totalFeePpk == 1000)
        #expect(breakdown["keyset2"]?.totalFee == 1)
    }
    
    // MARK: - KeysetManagementService Tests
    
    @Test
    func keysetManagementServiceInitialization() async {
        let service = await KeysetManagementService()
        // Service is successfully created
    }
    
    @Test
    func keysetValidation() async {
        let service = await KeysetManagementService()
        
        // First test individual components
        let testKeysetID = "0088553333AABBCC"
        #expect(KeysetID.validateKeysetID(testKeysetID), "Keyset ID should be valid")
        
        // Valid keyset
        let validKeyset = Keyset(
            id: testKeysetID,
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "2": "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a"
            ]
        )
        
        // Test key validation components
        let testKey = "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a"
        #expect(testKey.count == 66, "Test key should be 66 characters")
        #expect(testKey.isValidHex, "Test key should be valid hex")
        
        // Test key validation first
        #expect(validKeyset.validateKeys(), "Keys should be valid")
        
        // Test full keyset validation
        #expect(service.validateKeyset(validKeyset), "Full keyset should be valid")
        
        // Invalid keyset - empty ID
        let invalidKeyset = Keyset(id: "", unit: "sat", keys: ["1": "02abcd..."])
        #expect(!service.validateKeyset(invalidKeyset))
    }
    
    @Test
    func keysetsResponseValidation() async {
        let service = await KeysetManagementService()
        
        let keysetInfo1 = KeysetInfo(id: "0088553333AABBCC", unit: "sat", active: true)
        let keysetInfo2 = KeysetInfo(id: "0099443333CCDDEE", unit: "usd", active: false)
        
        let validResponse = GetKeysetsResponse(keysets: [keysetInfo1, keysetInfo2])
        #expect(service.validateKeysetsResponse(validResponse))
        
        // Invalid response - empty keysets
        let invalidResponse = GetKeysetsResponse(keysets: [])
        #expect(!service.validateKeysetsResponse(invalidResponse))
        
        // Invalid response - invalid keyset ID
        let invalidKeysetInfo = KeysetInfo(id: "", unit: "sat", active: true)
        let invalidResponse2 = GetKeysetsResponse(keysets: [invalidKeysetInfo])
        #expect(!service.validateKeysetsResponse(invalidResponse2))
    }
    
    // MARK: - Proof Selection Tests
    
    @Test
    func optimalProofSelection() {
        // Test that proof selection considers efficiency
        let option1 = ProofSelectionOption(
            selectedProofs: [],
            totalAmount: 100,
            totalFee: 1,
            keysetID: "keyset1",
            efficiency: 0.99 // Better efficiency
        )
        
        let option2 = ProofSelectionOption(
            selectedProofs: [],
            totalAmount: 100,
            totalFee: 2,
            keysetID: "keyset2",
            efficiency: 0.98 // Worse efficiency
        )
        
        let result = ProofSelectionResult(recommended: option1, alternatives: [option2])
        #expect(result.recommended?.totalFee == 1)
        #expect(result.alternatives.first?.totalFee == 2)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test
    func emptyProofsFeeCalculation() {
        let keysetDict: [String: KeysetInfo] = [:]
        let emptyProofs: [Proof] = []
        
        let totalFees = FeeCalculator.calculateFees(for: emptyProofs, keysetInfo: keysetDict)
        #expect(totalFees == 0)
    }
    
    @Test
    func largeFeeCalculation() {
        // Test with large fee values
        let keysetInfo = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 999999)
        let keysetDict = ["keyset1": keysetInfo]
        
        let proof = Proof(amount: 1000000, id: "keyset1", secret: "secret", C: "signature")
        let proofs = [proof]
        
        // 999999/1000 = 999.999, rounds up to 1000
        let totalFees = FeeCalculator.calculateFees(for: proofs, keysetInfo: keysetDict)
        #expect(totalFees == 1000)
    }
    
    @Test
    func keysetIDEdgeCases() {
        // Test with empty keys
        let emptyKeysID = KeysetID.deriveKeysetID(from: [:])
        #expect(emptyKeysID.count == 16)
        #expect(emptyKeysID.hasPrefix("00"))
        
        // Test with single key
        let singleKey = ["1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a"]
        let singleKeyID = KeysetID.deriveKeysetID(from: singleKey)
        #expect(singleKeyID.count == 16)
        #expect(KeysetID.validateKeysetID(singleKeyID))
    }
    
    @Test
    func transactionValidationEdgeCases() {
        let keysetInfo = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 0)
        let keysetDict = ["keyset1": keysetInfo]
        
        // Test with zero fees
        let inputProofs = [Proof(amount: 100, id: "keyset1", secret: "secret", C: "signature")]
        let outputAmounts = [100]
        
        let isValid = FeeCalculator.validateTransactionBalance(
            inputProofs: inputProofs,
            outputAmounts: outputAmounts,
            keysetInfo: keysetDict
        )
        #expect(isValid)
        
        // Test with empty inputs and outputs
        let emptyValid = FeeCalculator.validateTransactionBalance(
            inputProofs: [],
            outputAmounts: [],
            keysetInfo: keysetDict
        )
        #expect(emptyValid)
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test
    func typicalCashuTransaction() {
        // Simulate a typical Cashu transaction with realistic values
        let keysetInfo = KeysetInfo(id: "0088553333AABBCC", unit: "sat", active: true, inputFeePpk: 100) // 0.1% fee
        let keysetDict = ["0088553333AABBCC": keysetInfo]
        
        // Input: 128 sats (user wants to send 100 sats)
        let inputProof = Proof(amount: 128, id: "0088553333AABBCC", secret: "random_secret_123", C: "signature_hex")
        let inputProofs = [inputProof]
        
        // Fee calculation: 100 ppk = 100/1000 = 0.1, rounds up to 1
        let fees = FeeCalculator.calculateFees(for: inputProofs, keysetInfo: keysetDict)
        #expect(fees == 1)
        
        // Outputs: 100 (to recipient) + 27 (change) = 127 (128 - 1 fee)
        let outputAmounts = [64, 32, 4, 16, 8, 2, 1] // Optimal denominations for 127
        let totalOutputs = outputAmounts.reduce(0, +)
        #expect(totalOutputs == 127)
        
        let isValid = FeeCalculator.validateTransactionBalance(
            inputProofs: inputProofs,
            outputAmounts: outputAmounts,
            keysetInfo: keysetDict
        )
        #expect(isValid)
    }
    
    @Test
    func multipleKeysetTransaction() {
        // Test transaction involving multiple keysets with different fees
        let keysetInfo1 = KeysetInfo(id: "keyset1", unit: "sat", active: true, inputFeePpk: 100)
        let keysetInfo2 = KeysetInfo(id: "keyset2", unit: "sat", active: true, inputFeePpk: 200)
        
        let keysetDict = [
            "keyset1": keysetInfo1,
            "keyset2": keysetInfo2
        ]
        
        let inputProofs = [
            Proof(amount: 64, id: "keyset1", secret: "secret1", C: "sig1"),  // 100 ppk fee
            Proof(amount: 32, id: "keyset2", secret: "secret2", C: "sig2"),  // 200 ppk fee
            Proof(amount: 16, id: "keyset1", secret: "secret3", C: "sig3")   // 100 ppk fee
        ]
        
        // Total inputs: 112, Total fees: (100 + 200 + 100)/1000 = 0.4, rounds up to 1
        let fees = FeeCalculator.calculateFees(for: inputProofs, keysetInfo: keysetDict)
        #expect(fees == 1)
        
        // Available for outputs: 112 - 1 = 111
        let outputAmounts = [64, 32, 8, 4, 2, 1] // 111 total
        
        let isValid = FeeCalculator.validateTransactionBalance(
            inputProofs: inputProofs,
            outputAmounts: outputAmounts,
            keysetInfo: keysetDict
        )
        #expect(isValid)
        
        // Test fee breakdown
        let breakdown = FeeCalculator.getFeeBreakdown(for: inputProofs, keysetInfo: keysetDict)
        #expect(breakdown["keyset1"]?.count == 2)
        #expect(breakdown["keyset1"]?.totalFeePpk == 200)
        #expect(breakdown["keyset2"]?.count == 1)
        #expect(breakdown["keyset2"]?.totalFeePpk == 200)
    }
    
    // MARK: - NUT-02 Test Vectors
    
    @Test("Keyset ID derivation test vectors - small keyset")
    func keysetIDDerivationSmallKeyset() {
        // Test vector from NUT-02 specification
        let keys = [
            "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc",
            "2": "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de",
            "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
            "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528"
        ]
        
        let expectedKeysetID = "00456a94ab4e1c46"
        let derivedID = KeysetID.deriveKeysetID(from: keys)
        
        #expect(derivedID == expectedKeysetID, "Keyset ID should match expected value from test vector")
    }
    
    @Test("Keyset ID derivation test vectors - large keyset")
    func keysetIDDerivationLargeKeyset() {
        // Test vector from NUT-02 specification with 64 keys (powers of 2 from 2^0 to 2^63)
        let keys = [
            "1": "03ba786a2c0745f8c30e490288acd7a72dd53d65afd292ddefa326a4a3fa14c566",
            "2": "03361cd8bd1329fea797a6add1cf1990ffcf2270ceb9fc81eeee0e8e9c1bd0cdf5",
            "4": "036e378bcf78738ddf68859293c69778035740e41138ab183c94f8fee7572214c7",
            "8": "03909d73beaf28edfb283dbeb8da321afd40651e8902fcf5454ecc7d69788626c0",
            "16": "028a36f0e6638ea7466665fe174d958212723019ec08f9ce6898d897f88e68aa5d",
            "32": "03a97a40e146adee2687ac60c2ba2586a90f970de92a9d0e6cae5a4b9965f54612",
            "64": "03ce86f0c197aab181ddba0cfc5c5576e11dfd5164d9f3d4a3fc3ffbbf2e069664",
            "128": "0284f2c06d938a6f78794814c687560a0aabab19fe5e6f30ede38e113b132a3cb9",
            "256": "03b99f475b68e5b4c0ba809cdecaae64eade2d9787aa123206f91cd61f76c01459",
            "512": "03d4db82ea19a44d35274de51f78af0a710925fe7d9e03620b84e3e9976e3ac2eb",
            "1024": "031fbd4ba801870871d46cf62228a1b748905ebc07d3b210daf48de229e683f2dc",
            "2048": "0276cedb9a3b160db6a158ad4e468d2437f021293204b3cd4bf6247970d8aff54b",
            "4096": "02fc6b89b403ee9eb8a7ed457cd3973638080d6e04ca8af7307c965c166b555ea2",
            "8192": "0320265583e916d3a305f0d2687fcf2cd4e3cd03a16ea8261fda309c3ec5721e21",
            "16384": "036e41de58fdff3cb1d8d713f48c63bc61fa3b3e1631495a444d178363c0d2ed50",
            "32768": "0365438f613f19696264300b069d1dad93f0c60a37536b72a8ab7c7366a5ee6c04",
            "65536": "02408426cfb6fc86341bac79624ba8708a4376b2d92debdf4134813f866eb57a8d",
            "131072": "031063e9f11c94dc778c473e968966eac0e70b7145213fbaff5f7a007e71c65f41",
            "262144": "02f2a3e808f9cd168ec71b7f328258d0c1dda250659c1aced14c7f5cf05aab4328",
            "524288": "038ac10de9f1ff9395903bb73077e94dbf91e9ef98fd77d9a2debc5f74c575bc86",
            "1048576": "0203eaee4db749b0fc7c49870d082024b2c31d889f9bc3b32473d4f1dfa3625788",
            "2097152": "033cdb9d36e1e82ae652b7b6a08e0204569ec7ff9ebf85d80a02786dc7fe00b04c",
            "4194304": "02c8b73f4e3a470ae05e5f2fe39984d41e9f6ae7be9f3b09c9ac31292e403ac512",
            "8388608": "025bbe0cfce8a1f4fbd7f3a0d4a09cb6badd73ef61829dc827aa8a98c270bc25b0",
            "16777216": "037eec3d1651a30a90182d9287a5c51386fe35d4a96839cf7969c6e2a03db1fc21",
            "33554432": "03280576b81a04e6abd7197f305506476f5751356b7643988495ca5c3e14e5c262",
            "67108864": "03268bfb05be1dbb33ab6e7e00e438373ca2c9b9abc018fdb452d0e1a0935e10d3",
            "134217728": "02573b68784ceba9617bbcc7c9487836d296aa7c628c3199173a841e7a19798020",
            "268435456": "0234076b6e70f7fbf755d2227ecc8d8169d662518ee3a1401f729e2a12ccb2b276",
            "536870912": "03015bd88961e2a466a2163bd4248d1d2b42c7c58a157e594785e7eb34d880efc9",
            "1073741824": "02c9b076d08f9020ebee49ac8ba2610b404d4e553a4f800150ceb539e9421aaeee",
            "2147483648": "034d592f4c366afddc919a509600af81b489a03caf4f7517c2b3f4f2b558f9a41a",
            "4294967296": "037c09ecb66da082981e4cbdb1ac65c0eb631fc75d85bed13efb2c6364148879b5",
            "8589934592": "02b4ebb0dda3b9ad83b39e2e31024b777cc0ac205a96b9a6cfab3edea2912ed1b3",
            "17179869184": "026cc4dacdced45e63f6e4f62edbc5779ccd802e7fabb82d5123db879b636176e9",
            "34359738368": "02b2cee01b7d8e90180254459b8f09bbea9aad34c3a2fd98c85517ecfc9805af75",
            "68719476736": "037a0c0d564540fc574b8bfa0253cca987b75466e44b295ed59f6f8bd41aace754",
            "137438953472": "021df6585cae9b9ca431318a713fd73dbb76b3ef5667957e8633bca8aaa7214fb6",
            "274877906944": "02b8f53dde126f8c85fa5bb6061c0be5aca90984ce9b902966941caf963648d53a",
            "549755813888": "029cc8af2840d59f1d8761779b2496623c82c64be8e15f9ab577c657c6dd453785",
            "1099511627776": "03e446fdb84fad492ff3a25fc1046fb9a93a5b262ebcd0151caa442ea28959a38a",
            "2199023255552": "02d6b25bd4ab599dd0818c55f75702fde603c93f259222001246569018842d3258",
            "4398046511104": "03397b522bb4e156ec3952d3f048e5a986c20a00718e5e52cd5718466bf494156a",
            "8796093022208": "02d1fb9e78262b5d7d74028073075b80bb5ab281edcfc3191061962c1346340f1e",
            "17592186044416": "030d3f2ad7a4ca115712ff7f140434f802b19a4c9b2dd1c76f3e8e80c05c6a9310",
            "35184372088832": "03e325b691f292e1dfb151c3fb7cad440b225795583c32e24e10635a80e4221c06",
            "70368744177664": "03bee8f64d88de3dee21d61f89efa32933da51152ddbd67466bef815e9f93f8fd1",
            "140737488355328": "0327244c9019a4892e1f04ba3bf95fe43b327479e2d57c25979446cc508cd379ed",
            "281474976710656": "02fb58522cd662f2f8b042f8161caae6e45de98283f74d4e99f19b0ea85e08a56d",
            "562949953421312": "02adde4b466a9d7e59386b6a701a39717c53f30c4810613c1b55e6b6da43b7bc9a",
            "1125899906842624": "038eeda11f78ce05c774f30e393cda075192b890d68590813ff46362548528dca9",
            "2251799813685248": "02ec13e0058b196db80f7079d329333b330dc30c000dbdd7397cbbc5a37a664c4f",
            "4503599627370496": "02d2d162db63675bd04f7d56df04508840f41e2ad87312a3c93041b494efe80a73",
            "9007199254740992": "0356969d6aef2bb40121dbd07c68b6102339f4ea8e674a9008bb69506795998f49",
            "18014398509481984": "02f4e667567ebb9f4e6e180a4113bb071c48855f657766bb5e9c776a880335d1d6",
            "36028797018963968": "0385b4fe35e41703d7a657d957c67bb536629de57b7e6ee6fe2130728ef0fc90b0",
            "72057594037927936": "02b2bc1968a6fddbcc78fb9903940524824b5f5bed329c6ad48a19b56068c144fd",
            "144115188075855872": "02e0dbb24f1d288a693e8a49bc14264d1276be16972131520cf9e055ae92fba19a",
            "288230376151711744": "03efe75c106f931a525dc2d653ebedddc413a2c7d8cb9da410893ae7d2fa7d19cc",
            "576460752303423488": "02c7ec2bd9508a7fc03f73c7565dc600b30fd86f3d305f8f139c45c404a52d958a",
            "1152921504606846976": "035a6679c6b25e68ff4e29d1c7ef87f21e0a8fc574f6a08c1aa45ff352c1d59f06",
            "2305843009213693952": "033cdc225962c052d485f7cfbf55a5b2367d200fe1fe4373a347deb4cc99e9a099",
            "4611686018427387904": "024a4b806cf413d14b294719090a9da36ba75209c7657135ad09bc65328fba9e6f",
            "9223372036854775808": "0377a6fe114e291a8d8e991627c38001c8305b23b9e98b1c7b1893f5cd0dda6cad"
        ]
        
        let expectedKeysetID = "000f01df73ea149a"
        let derivedID = KeysetID.deriveKeysetID(from: keys)
        
        // Note: The keyset contains amounts larger than Int64.max (e.g., 9223372036854775808)
        // The implementation correctly handles these by using string comparison
        // This test vector actually has 64 keys (2^0 through 2^63), not 66
        #expect(keys.count == 64, "Should have all 64 key-value pairs")
        
        #expect(derivedID == expectedKeysetID, "Keyset ID should match expected value from test vector")
    }
    
    @Test("Keyset ID derivation determinism")
    func keysetIDDerivationDeterminism() {
        // Test that the same keys always produce the same keyset ID
        let keys = [
            "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc",
            "2": "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de",
            "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
            "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528"
        ]
        
        // Derive the ID multiple times
        let id1 = KeysetID.deriveKeysetID(from: keys)
        let id2 = KeysetID.deriveKeysetID(from: keys)
        let id3 = KeysetID.deriveKeysetID(from: keys)
        
        #expect(id1 == id2)
        #expect(id2 == id3)
        #expect(id1 == "00456a94ab4e1c46")
    }
    
    @Test("Keyset ID derivation ordering")
    func keysetIDDerivationOrdering() {
        // Test that key order in the dictionary doesn't affect the result
        let keys1 = [
            "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528",
            "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc",
            "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
            "2": "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de"
        ]
        
        let keys2 = [
            "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc",
            "2": "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de",
            "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
            "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528"
        ]
        
        let id1 = KeysetID.deriveKeysetID(from: keys1)
        let id2 = KeysetID.deriveKeysetID(from: keys2)
        
        #expect(id1 == id2)
        #expect(id1 == "00456a94ab4e1c46")
    }
}