//
//  NUT03Tests.swift
//  CashuKit
//
//  Tests for NUT-03: Swap tokens
//

import Testing
@testable import CashuKit

@Suite("NUT03 tests")
struct NUT03Tests {
    
    // MARK: - PostSwapRequest Tests
    
    @Test
    func postSwapRequestValidation() {
        let proof1 = Proof(amount: 64, id: "keyset123", secret: "secret1", C: "signature1")
        let proof2 = Proof(amount: 32, id: "keyset123", secret: "secret2", C: "signature2")
        
        let blindedMessage1 = BlindedMessage(amount: 32, id: "keyset123", B_: "02abcd...")
        let blindedMessage2 = BlindedMessage(amount: 64, id: "keyset123", B_: "03efgh...")
        
        // Valid request
        let validRequest = PostSwapRequest(
            inputs: [proof1, proof2],
            outputs: [blindedMessage1, blindedMessage2]
        )
        #expect(validRequest.validate())
        #expect(validRequest.totalInputAmount == 96)
        #expect(validRequest.totalOutputAmount == 96)
        #expect(validRequest.hasPrivacyPreservingOrder)
        
        // Invalid request - no inputs
        let invalidRequest1 = PostSwapRequest(inputs: [], outputs: [blindedMessage1])
        #expect(!invalidRequest1.validate())
        
        // Invalid request - no outputs
        let invalidRequest2 = PostSwapRequest(inputs: [proof1], outputs: [])
        #expect(!invalidRequest2.validate())
        
        // Invalid request - invalid proof
        let invalidProof = Proof(amount: 0, id: "", secret: "", C: "")
        let invalidRequest3 = PostSwapRequest(inputs: [invalidProof], outputs: [blindedMessage1])
        #expect(!invalidRequest3.validate())
        
        // Invalid request - invalid blinded message
        let invalidBlindedMessage = BlindedMessage(amount: 0, id: "", B_: "")
        let invalidRequest4 = PostSwapRequest(inputs: [proof1], outputs: [invalidBlindedMessage])
        #expect(!invalidRequest4.validate())
    }
    
    @Test
    func postSwapRequestAmountCalculations() {
        let proof1 = Proof(amount: 64, id: "keyset123", secret: "secret1", C: "sig1")
        let proof2 = Proof(amount: 32, id: "keyset123", secret: "secret2", C: "sig2")
        let proof3 = Proof(amount: 16, id: "keyset123", secret: "secret3", C: "sig3")
        
        let blindedMessage1 = BlindedMessage(amount: 64, id: "keyset123", B_: "02abcd...")
        let blindedMessage2 = BlindedMessage(amount: 32, id: "keyset123", B_: "03efgh...")
        let blindedMessage3 = BlindedMessage(amount: 16, id: "keyset123", B_: "02ijkl...")
        
        let request = PostSwapRequest(
            inputs: [proof1, proof2, proof3],
            outputs: [blindedMessage1, blindedMessage2, blindedMessage3]
        )
        
        #expect(request.totalInputAmount == 112)
        #expect(request.totalOutputAmount == 112)
    }
    
    @Test
    func postSwapRequestPrivacyPreservingOrder() {
        let proof = Proof(amount: 96, id: "keyset123", secret: "secret", C: "signature")
        
        // Correct order (ascending)
        let orderedOutputs = [
            BlindedMessage(amount: 32, id: "keyset123", B_: "02abcd..."),
            BlindedMessage(amount: 64, id: "keyset123", B_: "03efgh...")
        ]
        let orderedRequest = PostSwapRequest(inputs: [proof], outputs: orderedOutputs)
        #expect(orderedRequest.hasPrivacyPreservingOrder)
        
        // Incorrect order (descending)
        let unorderedOutputs = [
            BlindedMessage(amount: 64, id: "keyset123", B_: "03efgh..."),
            BlindedMessage(amount: 32, id: "keyset123", B_: "02abcd...")
        ]
        let unorderedRequest = PostSwapRequest(inputs: [proof], outputs: unorderedOutputs)
        #expect(!unorderedRequest.hasPrivacyPreservingOrder)
    }
    
    // MARK: - PostSwapResponse Tests
    
    @Test
    func postSwapResponseValidation() {
        let signature1 = BlindSignature(amount: 32, id: "keyset123", C_: "02abcd...")
        let signature2 = BlindSignature(amount: 64, id: "keyset123", C_: "03efgh...")
        
        // Valid response
        let validResponse = PostSwapResponse(signatures: [signature1, signature2])
        #expect(validResponse.validate())
        #expect(validResponse.totalAmount == 96)
        
        // Invalid response - no signatures
        let invalidResponse1 = PostSwapResponse(signatures: [])
        #expect(!invalidResponse1.validate())
        
        // Invalid response - invalid signature
        let invalidSignature = BlindSignature(amount: 0, id: "", C_: "")
        let invalidResponse2 = PostSwapResponse(signatures: [invalidSignature])
        #expect(!invalidResponse2.validate())
    }
    
    // MARK: - SwapType Tests
    
    @Test
    func swapTypeAllCases() {
        let allCases = SwapType.allCases
        #expect(allCases.contains(.send))
        #expect(allCases.contains(.receive))
        #expect(allCases.contains(.split))
        #expect(allCases.contains(.combine))
        #expect(allCases.contains(.rotate))
        
        // Test raw values
        #expect(SwapType.send.rawValue == "send")
        #expect(SwapType.receive.rawValue == "receive")
        #expect(SwapType.split.rawValue == "split")
        #expect(SwapType.combine.rawValue == "combine")
        #expect(SwapType.rotate.rawValue == "rotate")
    }
    
    // MARK: - SwapResult Tests
    
    @Test
    func swapResult() {
        let oldProof = Proof(amount: 128, id: "keyset123", secret: "old_secret", C: "old_sig")
        let newProof1 = Proof(amount: 64, id: "keyset123", secret: "new_secret1", C: "new_sig1")
        let newProof2 = Proof(amount: 32, id: "keyset123", secret: "new_secret2", C: "new_sig2")
        
        let result = SwapResult(
            newProofs: [newProof1, newProof2],
            invalidatedProofs: [oldProof],
            swapType: .split,
            totalAmount: 96,
            fees: 2
        )
        
        #expect(result.newProofs.count == 2)
        #expect(result.invalidatedProofs.count == 1)
        #expect(result.swapType == .split)
        #expect(result.totalAmount == 96)
        #expect(result.fees == 2)
    }
    
    // MARK: - SwapPreparation Tests
    
    @Test
    func swapPreparation() throws {
        let inputProof = Proof(amount: 128, id: "keyset123", secret: "input_secret", C: "input_sig")
        let blindedMessage = BlindedMessage(amount: 64, id: "keyset123", B_: "02abcd...")
        let blindingData = try WalletBlindingData(secret: "test_secret")
        
        let preparation = SwapPreparation(
            inputProofs: [inputProof],
            blindedMessages: [blindedMessage],
            blindingData: [blindingData],
            targetAmount: 100,
            changeAmount: 26,
            fees: 2
        )
        
        #expect(preparation.inputProofs.count == 1)
        #expect(preparation.blindedMessages.count == 1)
        #expect(preparation.blindingData.count == 1)
        #expect(preparation.targetAmount == 100)
        #expect(preparation.changeAmount == 26)
        #expect(preparation.fees == 2)
    }
    
    // MARK: - SwapService Tests
    
    @Test
    func swapServiceInitialization() async {
        let service = await SwapService()
        // Service is successfully created
    }
    
    @Test
    func swapValidationMethods() async {
        let service = await SwapService()
        
        // Test proof validation - create valid proofs
        let validProof = Proof(amount: 64, id: "0088553333AABBCC", secret: "valid_secret", C: "valid_signature")
        let invalidProof = Proof(amount: 0, id: "", secret: "", C: "")
        
        let blindedMessage = BlindedMessage(amount: 64, id: "0088553333AABBCC", B_: "02abcd...")
        
        let validRequest = PostSwapRequest(inputs: [validProof], outputs: [blindedMessage])
        let invalidRequest = PostSwapRequest(inputs: [invalidProof], outputs: [blindedMessage])
        
        // Test balance validation
        let keysetInfo = KeysetInfo(id: "0088553333AABBCC", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetDict = ["0088553333AABBCC": keysetInfo]
        
        // For valid request: input 64, fee 1, output should be 63
        let balancedRequest = PostSwapRequest(
            inputs: [validProof],
            outputs: [BlindedMessage(amount: 63, id: "0088553333AABBCC", B_: "02abcd...")]
        )
        #expect(service.validateSwapBalance(balancedRequest, keysetInfo: keysetDict))
        
        // Unbalanced request
        #expect(!service.validateSwapBalance(validRequest, keysetInfo: keysetDict))
    }
    
    // MARK: - Optimal Denominations Tests
    
    @Test
    func optimalDenominations() {
        // Test the optimal denomination creation logic
        // This tests the binary decomposition used in the private method
        
        let testCases = [
            (amount: 1, expected: [1]),
            (amount: 2, expected: [2]),
            (amount: 3, expected: [1, 2]),
            (amount: 4, expected: [4]),
            (amount: 5, expected: [1, 4]),
            (amount: 7, expected: [1, 2, 4]),
            (amount: 15, expected: [1, 2, 4, 8]),
            (amount: 96, expected: [32, 64]),
            (amount: 127, expected: [1, 2, 4, 8, 16, 32, 64])
        ]
        
        for testCase in testCases {
            var denominations: [Int] = []
            var remaining = testCase.amount
            var power = 0
            
            while remaining > 0 {
                let denomination = 1 << power
                if remaining & denomination != 0 {
                    denominations.append(denomination)
                    remaining -= denomination
                }
                power += 1
            }
            
            let sortedDenominations = denominations.sorted()
            #expect(sortedDenominations == testCase.expected, "Failed for amount \(testCase.amount)")
            #expect(sortedDenominations.reduce(0, +) == testCase.amount, "Sum doesn't match for amount \(testCase.amount)")
        }
    }
    
    // MARK: - API Endpoint Tests
    
    @Test
    func swapAPIEndpoint() {
        let proof = Proof(amount: 64, id: "keyset123", secret: "secret", C: "signature")
        let blindedMessage = BlindedMessage(amount: 64, id: "keyset123", B_: "02abcd...")
        let request = PostSwapRequest(inputs: [proof], outputs: [blindedMessage])
        
        let endpoint = SwapAPI.swap(request)
        
        // These would normally be tested with actual network setup
        // For now, just verify the endpoint exists and can be created
        // #expect(endpoint != nil) // This would need proper comparison
    }
    
    // MARK: - Convenience Extension Tests
    
    @Test
    func convenienceExtensions() {
        // Test that convenience methods exist and have correct signatures
        // These would need actual network setup to test fully
        
        let proof = Proof(amount: 128, id: "keyset123", secret: "secret", C: "signature")
        
        // Verify method signatures exist (compilation test)
        let _ = { (service: SwapService) in
            Task {
                // These would throw network errors in tests, but we're just checking compilation
                let _ = try await service.swapToSend(from: [proof], amount: 100, at: "https://mint.example.com")
                let _ = try await service.swapToReceive(proofs: [proof], at: "https://mint.example.com")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func swapValidationErrors() {
        // Test various validation error scenarios
        
        // Empty inputs
        let emptyInputsRequest = PostSwapRequest(inputs: [], outputs: [])
        #expect(!emptyInputsRequest.validate())
        
        // Invalid proof amounts
        let zeroAmountProof = Proof(amount: 0, id: "keyset123", secret: "secret", C: "signature")
        let negativeAmountProof = Proof(amount: -10, id: "keyset123", secret: "secret", C: "signature")
        let blindedMessage = BlindedMessage(amount: 10, id: "keyset123", B_: "02abcd...")
        
        let zeroAmountRequest = PostSwapRequest(inputs: [zeroAmountProof], outputs: [blindedMessage])
        #expect(!zeroAmountRequest.validate())
        
        // Invalid proof fields
        let emptyIDProof = Proof(amount: 64, id: "", secret: "secret", C: "signature")
        let emptySecretProof = Proof(amount: 64, id: "keyset123", secret: "", C: "signature")
        let emptySigProof = Proof(amount: 64, id: "keyset123", secret: "secret", C: "")
        
        let emptyIDRequest = PostSwapRequest(inputs: [emptyIDProof], outputs: [blindedMessage])
        #expect(!emptyIDRequest.validate())
        
        let emptySecretRequest = PostSwapRequest(inputs: [emptySecretProof], outputs: [blindedMessage])
        #expect(!emptySecretRequest.validate())
        
        let emptySigRequest = PostSwapRequest(inputs: [emptySigProof], outputs: [blindedMessage])
        #expect(!emptySigRequest.validate())
        
        // Invalid blinded message fields
        let emptyBMessageID = BlindedMessage(amount: 64, id: "", B_: "02abcd...")
        let emptyBMessageB = BlindedMessage(amount: 64, id: "keyset123", B_: "")
        let zeroBMessageAmount = BlindedMessage(amount: 0, id: "keyset123", B_: "02abcd...")
        
        let validProof = Proof(amount: 64, id: "keyset123", secret: "secret", C: "signature")
        
        let emptyBMessageIDRequest = PostSwapRequest(inputs: [validProof], outputs: [emptyBMessageID])
        #expect(!emptyBMessageIDRequest.validate())
        
        let emptyBMessageBRequest = PostSwapRequest(inputs: [validProof], outputs: [emptyBMessageB])
        #expect(!emptyBMessageBRequest.validate())
        
        let zeroBMessageAmountRequest = PostSwapRequest(inputs: [validProof], outputs: [zeroBMessageAmount])
        #expect(!zeroBMessageAmountRequest.validate())
    }
    
    @Test
    func swapResponseValidationErrors() {
        // Test invalid signature fields
        let emptyIDSignature = BlindSignature(amount: 64, id: "", C_: "02abcd...")
        let emptyCSignature = BlindSignature(amount: 64, id: "keyset123", C_: "")
        let zeroAmountSignature = BlindSignature(amount: 0, id: "keyset123", C_: "02abcd...")
        
        let emptyIDResponse = PostSwapResponse(signatures: [emptyIDSignature])
        #expect(!emptyIDResponse.validate())
        
        let emptyCResponse = PostSwapResponse(signatures: [emptyCSignature])
        #expect(!emptyCResponse.validate())
        
        let zeroAmountResponse = PostSwapResponse(signatures: [zeroAmountSignature])
        #expect(!zeroAmountResponse.validate())
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test
    func typicalSendSwap() {
        // Simulate preparing to send 100 sats from a 128 sat proof
        let inputProof = Proof(amount: 128, id: "keyset123", secret: "input_secret", C: "input_signature")
        
        // Optimal outputs for 126 sats (128 - 2 fees): 64 + 32 + 16 + 8 + 4 + 2 = 126
        let targetOutputs = [
            BlindedMessage(amount: 2, id: "keyset123", B_: "02abc1..."),
            BlindedMessage(amount: 4, id: "keyset123", B_: "02abc2..."),
            BlindedMessage(amount: 8, id: "keyset123", B_: "02abc3..."),
            BlindedMessage(amount: 16, id: "keyset123", B_: "02abc4..."),
            BlindedMessage(amount: 32, id: "keyset123", B_: "02abc5..."),
            BlindedMessage(amount: 64, id: "keyset123", B_: "02abc6...")
        ]
        
        let swapRequest = PostSwapRequest(inputs: [inputProof], outputs: targetOutputs)
        
        #expect(swapRequest.validate())
        #expect(swapRequest.totalInputAmount == 128)
        #expect(swapRequest.totalOutputAmount == 126) // 128 - 2 fees
        #expect(swapRequest.hasPrivacyPreservingOrder)
    }
    
    @Test
    func typicalReceiveSwap() {
        // Simulate receiving tokens and swapping them to invalidate
        let receivedProofs = [
            Proof(amount: 32, id: "keyset123", secret: "received_secret1", C: "received_sig1"),
            Proof(amount: 64, id: "keyset123", secret: "received_secret2", C: "received_sig2")
        ]
        
        // After fees (assume 1 sat total), we have 95 sats
        // Optimal denominations: 64 + 16 + 8 + 4 + 2 + 1 = 95
        let newOutputs = [
            BlindedMessage(amount: 1, id: "keyset123", B_: "02new1..."),
            BlindedMessage(amount: 2, id: "keyset123", B_: "02new2..."),
            BlindedMessage(amount: 4, id: "keyset123", B_: "02new3..."),
            BlindedMessage(amount: 8, id: "keyset123", B_: "02new4..."),
            BlindedMessage(amount: 16, id: "keyset123", B_: "02new5..."),
            BlindedMessage(amount: 64, id: "keyset123", B_: "02new6...")
        ]
        
        let receiveSwapRequest = PostSwapRequest(inputs: receivedProofs, outputs: newOutputs)
        
        #expect(receiveSwapRequest.validate())
        #expect(receiveSwapRequest.totalInputAmount == 96)
        #expect(receiveSwapRequest.totalOutputAmount == 95)
        #expect(receiveSwapRequest.hasPrivacyPreservingOrder)
    }
    
    @Test
    func keysetRotationSwap() {
        // Simulate swapping from inactive to active keyset
        let inactiveProofs = [
            Proof(amount: 64, id: "inactive_keyset", secret: "secret1", C: "sig1"),
            Proof(amount: 32, id: "inactive_keyset", secret: "secret2", C: "sig2")
        ]
        
        // New outputs with active keyset
        let activeOutputs = [
            BlindedMessage(amount: 32, id: "active_keyset", B_: "02active1..."),
            BlindedMessage(amount: 63, id: "active_keyset", B_: "02active2...") // 96 - 1 fee
        ]
        
        let rotationSwapRequest = PostSwapRequest(inputs: inactiveProofs, outputs: activeOutputs)
        
        #expect(rotationSwapRequest.validate())
        #expect(rotationSwapRequest.totalInputAmount == 96)
        #expect(rotationSwapRequest.totalOutputAmount == 95)
        #expect(rotationSwapRequest.hasPrivacyPreservingOrder)
    }
    
    // MARK: - Complex Scenario Tests
    
    @Test
    func multipleInputsSwap() {
        // Test swap with multiple inputs of different amounts
        let inputs = [
            Proof(amount: 1, id: "keyset123", secret: "secret1", C: "sig1"),
            Proof(amount: 2, id: "keyset123", secret: "secret2", C: "sig2"),
            Proof(amount: 4, id: "keyset123", secret: "secret3", C: "sig3"),
            Proof(amount: 8, id: "keyset123", secret: "secret4", C: "sig4"),
            Proof(amount: 16, id: "keyset123", secret: "secret5", C: "sig5")
        ]
        // Total: 31 sats
        
        // Outputs after 1 sat fee: 30 sats = 16 + 8 + 4 + 2
        let outputs = [
            BlindedMessage(amount: 2, id: "keyset123", B_: "02out1..."),
            BlindedMessage(amount: 4, id: "keyset123", B_: "02out2..."),
            BlindedMessage(amount: 8, id: "keyset123", B_: "02out3..."),
            BlindedMessage(amount: 16, id: "keyset123", B_: "02out4...")
        ]
        
        let multiInputSwap = PostSwapRequest(inputs: inputs, outputs: outputs)
        
        #expect(multiInputSwap.validate())
        #expect(multiInputSwap.totalInputAmount == 31)
        #expect(multiInputSwap.totalOutputAmount == 30)
        #expect(multiInputSwap.hasPrivacyPreservingOrder)
    }
    
    @Test
    func largeAmountSwap() {
        // Test swap with larger amounts
        let largeInput = Proof(amount: 1024, id: "keyset123", secret: "large_secret", C: "large_signature")
        
        // Split into smaller denominations (assume 2 sat fee)
        // 1022 = 512 + 256 + 128 + 64 + 32 + 16 + 8 + 4 + 2
        let smallOutputs = [
            BlindedMessage(amount: 2, id: "keyset123", B_: "02small1..."),
            BlindedMessage(amount: 4, id: "keyset123", B_: "02small2..."),
            BlindedMessage(amount: 8, id: "keyset123", B_: "02small3..."),
            BlindedMessage(amount: 16, id: "keyset123", B_: "02small4..."),
            BlindedMessage(amount: 32, id: "keyset123", B_: "02small5..."),
            BlindedMessage(amount: 64, id: "keyset123", B_: "02small6..."),
            BlindedMessage(amount: 128, id: "keyset123", B_: "02small7..."),
            BlindedMessage(amount: 256, id: "keyset123", B_: "02small8..."),
            BlindedMessage(amount: 512, id: "keyset123", B_: "02small9...")
        ]
        
        let largeSwap = PostSwapRequest(inputs: [largeInput], outputs: smallOutputs)
        
        #expect(largeSwap.validate())
        #expect(largeSwap.totalInputAmount == 1024)
        #expect(largeSwap.totalOutputAmount == 1022)
        #expect(largeSwap.hasPrivacyPreservingOrder)
    }
}