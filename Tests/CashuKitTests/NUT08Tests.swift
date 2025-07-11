//
//  NUT08Tests.swift
//  CashuKit
//
//  Tests for NUT-08: Lightning fee return
//

import Testing
import Foundation
@testable import CashuKit

@Suite("NUT08 tests")
struct NUT08Tests {
    
    // MARK: - FeeReturnCalculator Tests
    
    @Test
    func feeReturnCalculatorBlankOutputCount() {
        // Test edge cases
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 0) == 0)
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 1) == 1)
        
        // Test examples from the specification
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 1000) == 10) // ceil(log2(1000)) = 10
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 512) == 9)   // ceil(log2(512)) = 9
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 256) == 8)   // ceil(log2(256)) = 8
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 100) == 7)   // ceil(log2(100)) = 7
        
        // Test powers of 2
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 2) == 1)
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 4) == 2)
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 8) == 3)
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 16) == 4)
        
        // Test large values
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 65536) == 16)
    }
    
    @Test
    func feeReturnCalculatorOptimalDenominations() {
        // Test zero
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(0).isEmpty)
        
        // Test powers of 2
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(1) == [1])
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(2) == [2])
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(4) == [4])
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(8) == [8])
        
        // Test composite amounts
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(3) == [1, 2])
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(5) == [1, 4])
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(7) == [1, 2, 4])
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(15) == [1, 2, 4, 8])
        
        // Test example from specification: 900 -> [4, 128, 256, 512]
        let decomposition900 = FeeReturnCalculator.decomposeToOptimalDenominations(900)
        #expect(decomposition900.contains(4))
        #expect(decomposition900.contains(128))
        #expect(decomposition900.contains(256))
        #expect(decomposition900.contains(512))
        #expect(decomposition900.reduce(0, +) == 900)
        
        // Test sorted order (privacy-preserving)
        let decomposition = FeeReturnCalculator.decomposeToOptimalDenominations(31)
        #expect(decomposition == decomposition.sorted())
    }
    
    @Test
    func feeReturnCalculatorOptimalFeeReserve() {
        #expect(FeeReturnCalculator.calculateOptimalFeeReserve(amount: 1000, estimatedFee: 0) == 0)
        #expect(FeeReturnCalculator.calculateOptimalFeeReserve(amount: 1000, estimatedFee: 10) == 20) // 2.0 safety margin
        #expect(FeeReturnCalculator.calculateOptimalFeeReserve(amount: 1000, estimatedFee: 50, safetyMargin: 3.0) == 150)
    }
    
    @Test
    func feeReturnCalculatorBlankOutputValidation() {
        #expect(FeeReturnCalculator.validateBlankOutputCapacity(blankOutputCount: 0, maxPossibleReturn: 0))
        #expect(FeeReturnCalculator.validateBlankOutputCapacity(blankOutputCount: 1, maxPossibleReturn: 1))
        #expect(FeeReturnCalculator.validateBlankOutputCapacity(blankOutputCount: 10, maxPossibleReturn: 1000))
        #expect(!FeeReturnCalculator.validateBlankOutputCapacity(blankOutputCount: 5, maxPossibleReturn: 100))
        
        // 10 blank outputs can represent up to 1023 (2^10 - 1)
        #expect(FeeReturnCalculator.validateBlankOutputCapacity(blankOutputCount: 10, maxPossibleReturn: 1023))
        #expect(!FeeReturnCalculator.validateBlankOutputCapacity(blankOutputCount: 10, maxPossibleReturn: 1024))
    }
    
    @Test
    func feeReturnCalculatorReturnEfficiency() {
        #expect(FeeReturnCalculator.calculateReturnEfficiency(returnedAmount: 0, feeReserve: 0) == 0.0)
        #expect(FeeReturnCalculator.calculateReturnEfficiency(returnedAmount: 0, feeReserve: 100) == 0.0)
        #expect(FeeReturnCalculator.calculateReturnEfficiency(returnedAmount: 50, feeReserve: 100) == 0.5)
        #expect(FeeReturnCalculator.calculateReturnEfficiency(returnedAmount: 100, feeReserve: 100) == 1.0)
    }
    
    // MARK: - BlankOutput Tests
    
    @Test
    func blankOutputCreation() async throws {
        let blankOutputs = try await BlankOutputGenerator.generateBlankOutputs(count: 5, keysetID: "test_keyset")
        
        #expect(blankOutputs.count == 5)
        
        for blankOutput in blankOutputs {
            #expect(blankOutput.blindedMessage.id == "test_keyset")
            #expect(blankOutput.blindedMessage.amount == 1) // Placeholder amount
            #expect(!blankOutput.blindedMessage.B_.isEmpty)
            #expect(!blankOutput.blindingData.secret.isEmpty)
        }
        
        // Ensure each blank output has unique secrets
        let secrets = Set(blankOutputs.map { $0.blindingData.secret })
        #expect(secrets.count == 5)
    }
    
    @Test
    func blankOutputZeroCount() async throws {
        let blankOutputs = try await BlankOutputGenerator.generateBlankOutputs(count: 0, keysetID: "test_keyset")
        #expect(blankOutputs.isEmpty)
    }
    
    // MARK: - PostMeltRequest with NUT-08 Tests
    
    @Test
    func postMeltRequestWithOutputs() {
        let proof = Proof(amount: 64, id: "keyset123", secret: "secret1", C: "signature1")
        let blindedMessage = BlindedMessage(amount: 1, id: "keyset123", B_: "02abcd...")
        
        // Test without outputs
        let requestWithoutOutputs = PostMeltRequest(quote: "quote123", inputs: [proof])
        #expect(!requestWithoutOutputs.supportsFeeReturn)
        #expect(requestWithoutOutputs.blankOutputCount == 0)
        #expect(requestWithoutOutputs.outputs == nil)
        
        // Test with outputs
        let requestWithOutputs = PostMeltRequest(quote: "quote123", inputs: [proof], outputs: [blindedMessage])
        #expect(requestWithOutputs.supportsFeeReturn)
        #expect(requestWithOutputs.blankOutputCount == 1)
        #expect(requestWithOutputs.outputs?.count == 1)
        
        // Test validation
        #expect(requestWithoutOutputs.validate())
        #expect(requestWithOutputs.validate())
        
        // Test invalid outputs
        let invalidBlindedMessage = BlindedMessage(amount: 1, id: "", B_: "")
        let invalidRequest = PostMeltRequest(quote: "quote123", inputs: [proof], outputs: [invalidBlindedMessage])
        #expect(!invalidRequest.validate())
    }
    
    // MARK: - PostMeltQuoteResponse with NUT-08 Tests
    
    @Test
    func postMeltQuoteResponseWithFeeReserve() {
        // Test without fee reserve
        let quoteWithoutFeeReserve = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: .unpaid,
            expiry: Int(Date().timeIntervalSince1970) + 3600
        )
        #expect(!quoteWithoutFeeReserve.supportsFeeReturn)
        #expect(quoteWithoutFeeReserve.recommendedBlankOutputs == 0)
        #expect(quoteWithoutFeeReserve.totalAmountWithFeeReserve == 1000)
        
        // Test with fee reserve
        let quoteWithFeeReserve = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: .unpaid,
            expiry: Int(Date().timeIntervalSince1970) + 3600,
            feeReserve: 500
        )
        #expect(quoteWithFeeReserve.supportsFeeReturn)
        #expect(quoteWithFeeReserve.recommendedBlankOutputs > 0)
        #expect(quoteWithFeeReserve.totalAmountWithFeeReserve == 1500)
        
        // Test zero fee reserve
        let quoteWithZeroFeeReserve = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: .unpaid,
            expiry: Int(Date().timeIntervalSince1970) + 3600,
            feeReserve: 0
        )
        #expect(!quoteWithZeroFeeReserve.supportsFeeReturn)
        #expect(quoteWithZeroFeeReserve.recommendedBlankOutputs == 0)
    }
    
    // MARK: - PostMeltResponse with NUT-08 Tests
    
    @Test
    func postMeltResponseWithChange() {
        let blindSignature = BlindSignature(amount: 100, id: "keyset123", C_: "signature")
        
        // Test without change
        let responseWithoutChange = PostMeltResponse(state: .paid)
        #expect(!responseWithoutChange.hasFeesReturned)
        #expect(responseWithoutChange.changeSignatureCount == 0)
        #expect(responseWithoutChange.totalChangeAmount == 0)
        
        // Test with change
        let responseWithChange = PostMeltResponse(state: .paid, change: [blindSignature])
        #expect(responseWithChange.hasFeesReturned)
        #expect(responseWithChange.changeSignatureCount == 1)
        #expect(responseWithChange.totalChangeAmount == 100)
        
        // Test validation
        #expect(responseWithoutChange.validate())
        #expect(responseWithChange.validate())
    }
    
    // MARK: - FeeReturnResult Tests
    
    @Test
    func feeReturnResultProperties() {
        let proof = Proof(amount: 100, id: "keyset123", secret: "secret", C: "signature")
        
        // Test without return
        let noReturn = FeeReturnResult(
            returnedAmount: 0,
            returnedProofs: [],
            blankOutputsUsed: 0,
            blankOutputsProvided: 5
        )
        #expect(!noReturn.hasReturn)
        #expect(noReturn.outputEfficiency == 0.0)
        
        // Test with return
        let withReturn = FeeReturnResult(
            returnedAmount: 100,
            returnedProofs: [proof],
            blankOutputsUsed: 3,
            blankOutputsProvided: 5
        )
        #expect(withReturn.hasReturn)
        #expect(withReturn.outputEfficiency == 0.6)
        
        // Test perfect efficiency
        let perfectEfficiency = FeeReturnResult(
            returnedAmount: 100,
            returnedProofs: [proof],
            blankOutputsUsed: 5,
            blankOutputsProvided: 5
        )
        #expect(perfectEfficiency.outputEfficiency == 1.0)
    }
    
    // MARK: - FeeReturnConfiguration Tests
    
    @Test
    func feeReturnConfiguration() {
        let config = FeeReturnConfiguration(keysetID: "keyset123", unit: "sat")
        #expect(config.keysetID == "keyset123")
        #expect(config.unit == "sat")
        #expect(config.maxBlankOutputs == 64) // Default value
        
        let customConfig = FeeReturnConfiguration(keysetID: "keyset456", unit: "usd", maxBlankOutputs: 32)
        #expect(customConfig.maxBlankOutputs == 32)
    }
    
    // MARK: - FeeReturnStatistics Tests
    
    @Test
    func feeReturnStatistics() {
        let stats = FeeReturnStatistics(
            totalPayments: 100,
            paymentsWithFeeReturn: 75,
            totalFeeReserve: 10000,
            totalFeesReturned: 7500,
            averageReturnEfficiency: 0.75,
            blankOutputUtilization: 0.6
        )
        
        #expect(stats.feeReturnRate == 0.75)
        #expect(stats.overallEfficiency == 0.75)
        
        // Test edge cases
        let emptyStats = FeeReturnStatistics(
            totalPayments: 0,
            paymentsWithFeeReturn: 0,
            totalFeeReserve: 0,
            totalFeesReturned: 0,
            averageReturnEfficiency: 0.0,
            blankOutputUtilization: 0.0
        )
        #expect(emptyStats.feeReturnRate == 0.0)
        #expect(emptyStats.overallEfficiency == 0.0)
    }
    
    // MARK: - Error Tests
    
    @Test
    func nut08Errors() {
        let invalidFeeReserveError = NUT08Error.invalidFeeReserve("negative value")
        #expect(invalidFeeReserveError.localizedDescription.contains("Invalid fee reserve"))
        
        let blankOutputError = NUT08Error.blankOutputGenerationFailed("key error")
        #expect(blankOutputError.localizedDescription.contains("Blank output generation failed"))
        
        let changeSignatureError = NUT08Error.invalidChangeSignatureOrder("wrong order")
        #expect(changeSignatureError.localizedDescription.contains("Invalid change signature order"))
        
        let missingKeyError = NUT08Error.missingMintPublicKey("amount 100")
        #expect(missingKeyError.localizedDescription.contains("Missing mint public key"))
        
        let processingError = NUT08Error.feeReturnProcessingFailed("unblinding failed")
        #expect(processingError.localizedDescription.contains("Fee return processing failed"))
        
        let insufficientOutputsError = NUT08Error.insufficientBlankOutputs(required: 10, provided: 5)
        #expect(insufficientOutputsError.localizedDescription.contains("Insufficient blank outputs"))
        
        let invalidAmountError = NUT08Error.invalidBlankOutputAmount("zero amount")
        #expect(invalidAmountError.localizedDescription.contains("Invalid blank output amount"))
    }
    
    // MARK: - Integration Tests
    
    @Test
    func blankOutputWorkflow() async throws {
        // Simulate the complete blank output workflow
        let feeReserve = 1000
        let keysetID = "test_keyset_123"
        
        // Calculate blank outputs needed
        let blankOutputCount = FeeReturnCalculator.calculateBlankOutputCount(feeReserve: feeReserve)
        #expect(blankOutputCount == 10)
        
        // Generate blank outputs
        let blankOutputs = try await BlankOutputGenerator.generateBlankOutputs(
            count: blankOutputCount,
            keysetID: keysetID
        )
        #expect(blankOutputs.count == blankOutputCount)
        
        // Verify all blank outputs have the correct keyset ID
        for blankOutput in blankOutputs {
            #expect(blankOutput.blindedMessage.id == keysetID)
            #expect(blankOutput.blindedMessage.amount == 1) // Placeholder
        }
        
        // Simulate decomposition of returned amount
        let returnedAmount = 900 // Example from spec
        let decomposition = FeeReturnCalculator.decomposeToOptimalDenominations(returnedAmount)
        
        // Verify decomposition is valid
        #expect(decomposition.reduce(0, +) == returnedAmount)
        #expect(decomposition.count <= blankOutputCount) // Should fit in blank outputs
        
        // Test efficiency
        let efficiency = FeeReturnCalculator.calculateReturnEfficiency(
            returnedAmount: returnedAmount,
            feeReserve: feeReserve
        )
        #expect(efficiency == 0.9)
    }
    
    @Test
    func postMeltRequestWorkflowWithFeeReturn() async throws {
        // Create a proof and blank outputs
        let proof = Proof(amount: 2000, id: "keyset123", secret: "secret1", C: "signature1")
        let blankOutputs = try await BlankOutputGenerator.generateBlankOutputs(
            count: 5,
            keysetID: "keyset123"
        )
        
        // Create melt request with fee return
        let request = PostMeltRequest(
            quote: "quote123",
            inputs: [proof],
            outputs: blankOutputs.map { $0.blindedMessage }
        )
        
        #expect(request.validate())
        #expect(request.supportsFeeReturn)
        #expect(request.blankOutputCount == 5)
        #expect(request.totalInputAmount == 2000)
        
        // Test JSON serialization
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let jsonData = try encoder.encode(request)
        let decodedRequest = try decoder.decode(PostMeltRequest.self, from: jsonData)
        
        #expect(decodedRequest.quote == request.quote)
        #expect(decodedRequest.inputs.count == request.inputs.count)
        #expect(decodedRequest.outputs?.count == request.outputs?.count)
        #expect(decodedRequest.supportsFeeReturn == request.supportsFeeReturn)
    }
    
    @Test
    func meltQuoteResponseWorkflowWithFeeReserve() throws {
        // Create quote with fee reserve
        let quote = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 100000, // 100,000 sats
            unit: "sat",
            state: .unpaid,
            expiry: Int(Date().timeIntervalSince1970) + 3600,
            feeReserve: 1000 // 1,000 sats fee reserve
        )
        
        #expect(quote.supportsFeeReturn)
        #expect(quote.recommendedBlankOutputs == 10) // ceil(log2(1000))
        #expect(quote.totalAmountWithFeeReserve == 101000)
        
        // Test JSON serialization with snake_case
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let jsonData = try encoder.encode(quote)
        let decodedQuote = try decoder.decode(PostMeltQuoteResponse.self, from: jsonData)
        
        #expect(decodedQuote.feeReserve == quote.feeReserve)
        #expect(decodedQuote.supportsFeeReturn == quote.supportsFeeReturn)
        #expect(decodedQuote.totalAmountWithFeeReserve == quote.totalAmountWithFeeReserve)
    }
    
    @Test
    func blankOutputCreationExtension() {
        let secret = "test_secret_123"
        let blindingData: WalletBlindingData
        
        do {
            blindingData = try WalletBlindingData(secret: secret)
        } catch {
            #expect(Bool(false), "Failed to create blinding data")
            return
        }
        
        let blankOutput = BlindedMessage.createBlankOutput(
            keysetID: "keyset123",
            blindingData: blindingData
        )
        
        #expect(blankOutput.amount == 1) // Placeholder amount
        #expect(blankOutput.id == "keyset123")
        #expect(!blankOutput.B_.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    @Test
    func blankOutputGenerationPerformance() async throws {
        let startTime = Date()
        
        // Generate a large number of blank outputs
        let blankOutputs = try await BlankOutputGenerator.generateBlankOutputs(
            count: 100,
            keysetID: "performance_test"
        )
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        #expect(blankOutputs.count == 100)
        #expect(elapsedTime < 5.0) // Should complete within 5 seconds
        
        // Verify uniqueness
        let secrets = Set(blankOutputs.map { $0.blindingData.secret })
        #expect(secrets.count == 100) // All secrets should be unique
    }
    
    @Test
    func feeReturnCalculationPerformance() {
        let startTime = Date()
        
        // Perform many calculations
        for feeReserve in 1...1000 {
            let blankOutputCount = FeeReturnCalculator.calculateBlankOutputCount(feeReserve: feeReserve)
            let decomposition = FeeReturnCalculator.decomposeToOptimalDenominations(feeReserve)
            
            #expect(blankOutputCount > 0)
            #expect(decomposition.reduce(0, +) == feeReserve)
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        #expect(elapsedTime < 1.0) // Should complete within 1 second
    }
    
    // MARK: - Edge Case Tests
    
    @Test
    func feeReturnEdgeCases() {
        // Test maximum fee reserve that can be handled
        let maxSafeFeeReserve = 1 << 20 // 2^20 = 1,048,576
        let blankOutputCount = FeeReturnCalculator.calculateBlankOutputCount(feeReserve: maxSafeFeeReserve)
        #expect(blankOutputCount == 20) // ceil(log2(1,048,576)) = 20
        
        // Test capacity validation
        #expect(FeeReturnCalculator.validateBlankOutputCapacity(
            blankOutputCount: 20, 
            maxPossibleReturn: maxSafeFeeReserve - 1  // 2^20 - 1 is the max that can be represented with 20 blank outputs
        ))
        
        // Test decomposition of large amounts
        let decomposition = FeeReturnCalculator.decomposeToOptimalDenominations(maxSafeFeeReserve)
        #expect(decomposition.reduce(0, +) == maxSafeFeeReserve)
        #expect(decomposition.count <= 20) // Should fit in blank outputs
        
        // Test very small amounts
        #expect(FeeReturnCalculator.calculateBlankOutputCount(feeReserve: 1) == 1)
        #expect(FeeReturnCalculator.decomposeToOptimalDenominations(1) == [1])
    }
}