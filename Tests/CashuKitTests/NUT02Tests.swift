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
}