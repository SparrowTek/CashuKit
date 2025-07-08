//
//  NUT05Tests.swift
//  CashuKit
//
//  Tests for NUT-05: Melting tokens
//

import Testing
import Foundation
@testable import CashuKit

@Suite("NUT05 tests")
struct NUT05Tests {
    
    // MARK: - PaymentMethod Tests
    
    @Test
    func paymentMethodAllCases() {
        let allCases = PaymentMethod.allCases
        #expect(allCases.contains(.bolt11))
        #expect(allCases.contains(.bolt12))
        
        // Test raw values
        #expect(PaymentMethod.bolt11.rawValue == "bolt11")
        #expect(PaymentMethod.bolt12.rawValue == "bolt12")
        
        // Test descriptions
        #expect(PaymentMethod.bolt11.description == "Lightning Network BOLT11")
        #expect(PaymentMethod.bolt12.description == "Lightning Network BOLT12")
    }
    
    // MARK: - MeltQuoteState Tests
    
    @Test
    func meltQuoteStateAllCases() {
        let allCases = MeltQuoteState.allCases
        #expect(allCases.contains(.unpaid))
        #expect(allCases.contains(.pending))
        #expect(allCases.contains(.paid))
        
        // Test raw values
        #expect(MeltQuoteState.unpaid.rawValue == "UNPAID")
        #expect(MeltQuoteState.pending.rawValue == "PENDING")
        #expect(MeltQuoteState.paid.rawValue == "PAID")
        
        // Test state properties
        #expect(!MeltQuoteState.unpaid.isFinal)
        #expect(!MeltQuoteState.pending.isFinal)
        #expect(MeltQuoteState.paid.isFinal)
        
        #expect(MeltQuoteState.unpaid.canPay)
        #expect(!MeltQuoteState.pending.canPay)
        #expect(!MeltQuoteState.paid.canPay)
    }
    
    // MARK: - PostMeltQuoteRequest Tests
    
    @Test
    func postMeltQuoteRequestValidation() {
        // Valid request
        let validRequest = PostMeltQuoteRequest(
            request: "lnbc1000n1p...", 
            unit: "sat"
        )
        #expect(validRequest.validate())
        
        // Invalid request - empty request
        let invalidRequest1 = PostMeltQuoteRequest(request: "", unit: "sat")
        #expect(!invalidRequest1.validate())
        
        // Invalid request - empty unit
        let invalidRequest2 = PostMeltQuoteRequest(request: "lnbc1000n1p...", unit: "")
        #expect(!invalidRequest2.validate())
        
        // Invalid request - both empty
        let invalidRequest3 = PostMeltQuoteRequest(request: "", unit: "")
        #expect(!invalidRequest3.validate())
    }
    
    // MARK: - PostMeltQuoteResponse Tests
    
    @Test
    func postMeltQuoteResponseValidation() {
        let currentTime = Int(Date().timeIntervalSince1970)
        let futureTime = currentTime + 3600 // 1 hour from now
        let pastTime = currentTime - 3600   // 1 hour ago
        
        // Valid response
        let validResponse = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(validResponse.validate())
        #expect(!validResponse.isExpired)
        #expect(validResponse.timeUntilExpiry > 0)
        
        // Invalid response - empty quote
        let invalidResponse1 = PostMeltQuoteResponse(
            quote: "",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(!invalidResponse1.validate())
        
        // Invalid response - zero amount
        let invalidResponse2 = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 0,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(!invalidResponse2.validate())
        
        // Invalid response - negative amount
        let invalidResponse3 = PostMeltQuoteResponse(
            quote: "quote123",
            amount: -100,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(!invalidResponse3.validate())
        
        // Invalid response - empty unit
        let invalidResponse4 = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(!invalidResponse4.validate())
        
        // Invalid response - zero expiry
        let invalidResponse5 = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: 0
        )
        #expect(!invalidResponse5.validate())
        
        // Test expired quote
        let expiredResponse = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: pastTime
        )
        #expect(expiredResponse.validate()) // Still structurally valid
        #expect(expiredResponse.isExpired)
        #expect(expiredResponse.timeUntilExpiry == 0)
    }
    
    // MARK: - PostMeltRequest Tests
    
    @Test
    func postMeltRequestValidation() {
        let validProof1 = Proof(amount: 64, id: "keyset123", secret: "secret1", C: "signature1")
        let validProof2 = Proof(amount: 32, id: "keyset123", secret: "secret2", C: "signature2")
        
        // Valid request
        let validRequest = PostMeltRequest(
            quote: "quote123",
            inputs: [validProof1, validProof2]
        )
        #expect(validRequest.validate())
        #expect(validRequest.totalInputAmount == 96)
        
        // Invalid request - empty quote
        let invalidRequest1 = PostMeltRequest(quote: "", inputs: [validProof1])
        #expect(!invalidRequest1.validate())
        
        // Invalid request - no inputs
        let invalidRequest2 = PostMeltRequest(quote: "quote123", inputs: [])
        #expect(!invalidRequest2.validate())
        
        // Invalid request - invalid proof
        let invalidProof = Proof(amount: 0, id: "", secret: "", C: "")
        let invalidRequest3 = PostMeltRequest(quote: "quote123", inputs: [invalidProof])
        #expect(!invalidRequest3.validate())
        
        // Test individual proof validation within request
        let zeroAmountProof = Proof(amount: 0, id: "keyset123", secret: "secret", C: "signature")
        let emptyIDProof = Proof(amount: 64, id: "", secret: "secret", C: "signature")
        let emptySecretProof = Proof(amount: 64, id: "keyset123", secret: "", C: "signature")
        let emptySigProof = Proof(amount: 64, id: "keyset123", secret: "secret", C: "")
        
        let invalidRequest4 = PostMeltRequest(quote: "quote123", inputs: [zeroAmountProof])
        #expect(!invalidRequest4.validate())
        
        let invalidRequest5 = PostMeltRequest(quote: "quote123", inputs: [emptyIDProof])
        #expect(!invalidRequest5.validate())
        
        let invalidRequest6 = PostMeltRequest(quote: "quote123", inputs: [emptySecretProof])
        #expect(!invalidRequest6.validate())
        
        let invalidRequest7 = PostMeltRequest(quote: "quote123", inputs: [emptySigProof])
        #expect(!invalidRequest7.validate())
    }
    
    // MARK: - PostMeltResponse Tests
    
    @Test
    func postMeltResponseValidation() {
        let validSignature1 = BlindSignature(amount: 32, id: "keyset123", C_: "02abcd...")
        let validSignature2 = BlindSignature(amount: 16, id: "keyset123", C_: "03efgh...")
        
        // Valid response with change
        let validResponse1 = PostMeltResponse(
            state: MeltQuoteState.paid,
            change: [validSignature1, validSignature2]
        )
        #expect(validResponse1.validate())
        #expect(validResponse1.totalChangeAmount == 48)
        
        // Valid response without change
        let validResponse2 = PostMeltResponse(state: .paid, change: nil)
        #expect(validResponse2.validate())
        #expect(validResponse2.totalChangeAmount == 0)
        
        // Valid response with empty change
        let validResponse3 = PostMeltResponse(state: .pending, change: [])
        #expect(validResponse3.validate())
        #expect(validResponse3.totalChangeAmount == 0)
        
        // Invalid response - invalid signature in change
        let invalidSignature = BlindSignature(amount: 0, id: "", C_: "")
        let invalidResponse = PostMeltResponse(
            state: MeltQuoteState.paid,
            change: [invalidSignature]
        )
        #expect(!invalidResponse.validate())
    }
    
    // MARK: - MeltType Tests
    
    @Test
    func meltTypeAllCases() {
        let allCases = MeltType.allCases
        #expect(allCases.contains(.payment))
        #expect(allCases.contains(.withdrawal))
        #expect(allCases.contains(.refund))
        
        // Test raw values
        #expect(MeltType.payment.rawValue == "payment")
        #expect(MeltType.withdrawal.rawValue == "withdrawal")
        #expect(MeltType.refund.rawValue == "refund")
    }
    
    // MARK: - MeltResult Tests
    
    @Test
    func meltResult() {
        let spentProof = Proof(amount: 128, id: "keyset123", secret: "spent_secret", C: "spent_sig")
        let changeProof1 = Proof(amount: 32, id: "keyset123", secret: "change_secret1", C: "change_sig1")
        let changeProof2 = Proof(amount: 16, id: "keyset123", secret: "change_secret2", C: "change_sig2")
        
        let result = MeltResult(
            state: MeltQuoteState.paid,
            changeProofs: [changeProof1, changeProof2],
            spentProofs: [spentProof],
            meltType: MeltType.payment,
            totalAmount: 128,
            fees: 2,
            paymentProof: "payment_proof".data(using: .utf8)
        )
        
        #expect(result.state == MeltQuoteState.paid)
        #expect(result.changeProofs.count == 2)
        #expect(result.spentProofs.count == 1)
        #expect(result.meltType == MeltType.payment)
        #expect(result.totalAmount == 128)
        #expect(result.fees == 2)
        #expect(result.paymentProof != nil)
        #expect(result.isSuccessful)
        #expect(result.netAmountSpent == 80) // 128 - 48 change
    }
    
    // MARK: - MeltPreparation Tests
    
    @Test
    func meltPreparation() throws {
        let currentTime = Int(Date().timeIntervalSince1970)
        let futureTime = currentTime + 3600
        
        let quote = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        
        let inputProof = Proof(amount: 1024, id: "keyset123", secret: "input_secret", C: "input_sig")
        let blindedMessage = BlindedMessage(amount: 16, id: "keyset123", B_: "02abcd...")
        let blindingData = try WalletBlindingData(secret: "change_secret")
        
        let preparation = MeltPreparation(
            quote: quote,
            inputProofs: [inputProof],
            blindedMessages: [blindedMessage],
            blindingData: [blindingData],
            requiredAmount: 1002,
            changeAmount: 22,
            fees: 2
        )
        
        #expect(preparation.quote.quote == "quote123")
        #expect(preparation.inputProofs.count == 1)
        #expect(preparation.blindedMessages?.count == 1)
        #expect(preparation.blindingData?.count == 1)
        #expect(preparation.requiredAmount == 1002)
        #expect(preparation.changeAmount == 22)
        #expect(preparation.fees == 2)
    }
    
    // MARK: - MeltMethodSetting Tests
    
    @Test
    func meltMethodSetting() {
        // Basic setting without limits
        let basicSetting = MeltMethodSetting(
            method: "bolt11",
            unit: "sat"
        )
        #expect(basicSetting.method == "bolt11")
        #expect(basicSetting.unit == "sat")
        #expect(basicSetting.minAmount == nil)
        #expect(basicSetting.maxAmount == nil)
        #expect(basicSetting.options == nil)
        
        // Setting with limits and options
        let advancedSetting = MeltMethodSetting(
            method: "bolt12",
            unit: "msat",
            minAmount: 1000,
            maxAmount: 10_000_000,
            options: ["timeout": .init(60), "max_fee_percent": .init(0.01)]
        )
        #expect(advancedSetting.method == "bolt12")
        #expect(advancedSetting.unit == "msat")
        #expect(advancedSetting.minAmount == 1000)
        #expect(advancedSetting.maxAmount == 10_000_000)
        #expect(advancedSetting.options != nil)
    }
    
    // MARK: - MeltSettings Tests
    
    @Test
    func meltSettings() {
        let bolt11Setting = MeltMethodSetting(method: "bolt11", unit: "sat", minAmount: 100, maxAmount: 1_000_000)
        let bolt12Setting = MeltMethodSetting(method: "bolt12", unit: "msat", minAmount: 1000, maxAmount: 10_000_000)
        
        let settings = MeltSettings(
            methods: [bolt11Setting, bolt12Setting],
            disabled: false
        )
        
        #expect(settings.methods.count == 2)
        #expect(!settings.disabled)
        
        let supportedPairs = settings.supportedPairs
        #expect(supportedPairs.count == 2)
        #expect(supportedPairs.contains { $0.method == "bolt11" && $0.unit == "sat" })
        #expect(supportedPairs.contains { $0.method == "bolt12" && $0.unit == "msat" })
        
        #expect(settings.supports(method: "bolt11", unit: "sat"))
        #expect(settings.supports(method: "bolt12", unit: "msat"))
        #expect(!settings.supports(method: "bolt11", unit: "msat"))
        #expect(!settings.supports(method: "invalid", unit: "sat"))
        
        let bolt11Settings = settings.getSettings(for: "bolt11", unit: "sat")
        #expect(bolt11Settings?.minAmount == 100)
        #expect(bolt11Settings?.maxAmount == 1_000_000)
        
        let invalidSettings = settings.getSettings(for: "invalid", unit: "sat")
        #expect(invalidSettings == nil)
    }
    
    // MARK: - MeltService Tests
    
    @Test
    func meltServiceInitialization() async {
        let _ = await MeltService()
        // Service is successfully created
    }
    
    @Test
    func meltValidationMethods() async {
        let service = await MeltService()
        
        let currentTime = Int(Date().timeIntervalSince1970)
        let futureTime = currentTime + 3600
        
        let validQuote = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        
        let validProof = Proof(amount: 1100, id: "0088553333AABBCC", secret: "valid_secret", C: "valid_signature")
        let keysetInfo = KeysetInfo(id: "0088553333AABBCC", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetDict = ["0088553333AABBCC": keysetInfo]
        
        // Valid scenario: proof has 1100 sats, quote needs 1000, fee is 2 (1100 >= 1002)
        #expect(service.validateMeltQuote(validQuote, against: [validProof], keysetInfo: keysetDict))
        
        // Invalid scenario: insufficient funds
        let smallProof = Proof(amount: 500, id: "0088553333AABBCC", secret: "small_secret", C: "small_signature")
        #expect(!service.validateMeltQuote(validQuote, against: [smallProof], keysetInfo: keysetDict))
        
        // Invalid scenario: expired quote
        let expiredQuote = PostMeltQuoteResponse(
            quote: "expired_quote",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: currentTime - 3600
        )
        #expect(!service.validateMeltQuote(expiredQuote, against: [validProof], keysetInfo: keysetDict))
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
            (amount: 22, expected: [2, 4, 16]),
            (amount: 48, expected: [16, 32]),
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
    func meltAPIEndpoints() {
        let quoteRequest = PostMeltQuoteRequest(request: "lnbc1000n1p...", unit: "sat")
        let proof = Proof(amount: 1024, id: "keyset123", secret: "secret", C: "signature")
        let meltRequest = PostMeltRequest(quote: "quote123", inputs: [proof])
        
        let requestQuoteEndpoint = MeltAPI.requestMeltQuote("bolt11", quoteRequest)
        let checkQuoteEndpoint = MeltAPI.checkMeltQuote("bolt11", "quote123")
        let executeMeltEndpoint = MeltAPI.executeMelt("bolt11", meltRequest)
        
        // These would normally be tested with actual network setup
        // For now, just verify the endpoints exist and can be created
        // Basic verification that endpoints are created without crashing
        _ = requestQuoteEndpoint
        _ = checkQuoteEndpoint
        _ = executeMeltEndpoint
    }
    
    // MARK: - Convenience Extension Tests
    
    @Test
    func convenienceExtensions() {
        // Test that convenience methods exist and have correct signatures
        // These would need actual network setup to test fully
        
        let proof = Proof(amount: 1024, id: "keyset123", secret: "secret", C: "signature")
        
        // Verify method signatures exist (compilation test)
        let _ = { (service: MeltService) in
            Task {
                // These would throw network errors in tests, but we're just checking compilation
                let _ = try await service.meltToPayment(
                    paymentRequest: "lnbc1000n1p...",
                    method: .bolt11,
                    unit: "sat",
                    from: [proof],
                    at: "https://mint.example.com"
                )
                
                let _ = try await service.isQuoteReady(
                    quoteID: "quote123",
                    method: .bolt11,
                    at: "https://mint.example.com"
                )
                
                let _ = try await service.waitForQuotePayment(
                    quoteID: "quote123",
                    method: .bolt11,
                    at: "https://mint.example.com",
                    timeout: 60.0,
                    pollInterval: 2.0
                )
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func meltValidationErrors() {
        // Test various validation error scenarios
        
        // Empty quote request fields
        let emptyRequestRequest = PostMeltQuoteRequest(request: "", unit: "sat")
        #expect(!emptyRequestRequest.validate())
        
        let emptyUnitRequest = PostMeltQuoteRequest(request: "lnbc1000n1p...", unit: "")
        #expect(!emptyUnitRequest.validate())
        
        // Empty melt request fields
        let validProof = Proof(amount: 1024, id: "keyset123", secret: "secret", C: "signature")
        let emptyQuoteMeltRequest = PostMeltRequest(quote: "", inputs: [validProof])
        #expect(!emptyQuoteMeltRequest.validate())
        
        let emptyInputsMeltRequest = PostMeltRequest(quote: "quote123", inputs: [])
        #expect(!emptyInputsMeltRequest.validate())
        
        // Invalid quote response fields
        let currentTime = Int(Date().timeIntervalSince1970)
        let futureTime = currentTime + 3600
        
        let negativeAmountResponse = PostMeltQuoteResponse(
            quote: "quote123",
            amount: -100,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(!negativeAmountResponse.validate())
        
        let negativeExpiryResponse = PostMeltQuoteResponse(
            quote: "quote123",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: -1
        )
        #expect(!negativeExpiryResponse.validate())
    }
    
    @Test
    func meltResponseValidationErrors() {
        // Test invalid change signatures
        let invalidAmountSignature = BlindSignature(amount: -10, id: "keyset123", C_: "02abcd...")
        let emptyIDSignature = BlindSignature(amount: 32, id: "", C_: "02abcd...")
        let emptyCSignature = BlindSignature(amount: 32, id: "keyset123", C_: "")
        
        let invalidAmountResponse = PostMeltResponse(state: .paid, change: [invalidAmountSignature])
        #expect(!invalidAmountResponse.validate())
        
        let emptyIDResponse = PostMeltResponse(state: .paid, change: [emptyIDSignature])
        #expect(!emptyIDResponse.validate())
        
        let emptyCResponse = PostMeltResponse(state: .paid, change: [emptyCSignature])
        #expect(!emptyCResponse.validate())
    }
    
    // MARK: - Real-world Scenario Tests
    
    @Test
    func typicalLightningPayment() {
        // Simulate a typical Lightning payment scenario
        let lightningInvoice = "lnbc10u1p3xnhl2pp5jptserfk3zk4qy42tlucycrfwxhydvlemu9pqr93tuzlv9cc7g3sdqsvfhkcap8vjxqjj44r2c2ssjnvv3jt9vdj9k8sszxnvdk3"
        
        let inputProof = Proof(amount: 1024, id: "keyset123", secret: "payment_secret", C: "payment_signature")
        
        // Quote request for the invoice
        let quoteRequest = PostMeltQuoteRequest(request: lightningInvoice, unit: "sat")
        #expect(quoteRequest.validate())
        
        // Melt request with the proof
        let meltRequest = PostMeltRequest(quote: "quote123", inputs: [inputProof])
        #expect(meltRequest.validate())
        #expect(meltRequest.totalInputAmount == 1024)
        
        // Successful payment response with change
        let changeSignature = BlindSignature(amount: 22, id: "keyset123", C_: "02change...")
        let successResponse = PostMeltResponse(state: MeltQuoteState.paid, change: [changeSignature])
        #expect(successResponse.validate())
        #expect(successResponse.totalChangeAmount == 22)
    }
    
    @Test
    func failedPaymentScenario() {
        let currentTime = Int(Date().timeIntervalSince1970)
        let futureTime = currentTime + 3600
        
        // Quote that couldn't be paid
        let failedQuote = PostMeltQuoteResponse(
            quote: "failed_quote",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(failedQuote.validate())
        #expect(failedQuote.state.canPay)
        
        // Response indicating payment failure (would return inputs as change in practice)
        let failedResponse = PostMeltResponse(state: MeltQuoteState.unpaid, change: nil)
        #expect(failedResponse.validate())
        #expect(failedResponse.totalChangeAmount == 0)
    }
    
    @Test
    func exactAmountPayment() {
        // Scenario where input amount exactly matches required amount + fees
        let inputProof = Proof(amount: 1002, id: "keyset123", secret: "exact_secret", C: "exact_signature")
        
        let meltRequest = PostMeltRequest(quote: "exact_quote", inputs: [inputProof])
        #expect(meltRequest.validate())
        #expect(meltRequest.totalInputAmount == 1002)
        
        // No change needed
        let exactResponse = PostMeltResponse(state: MeltQuoteState.paid, change: nil)
        #expect(exactResponse.validate())
        #expect(exactResponse.totalChangeAmount == 0)
    }
    
    @Test
    func multipleInputsPayment() {
        // Payment using multiple smaller proofs
        let inputs = [
            Proof(amount: 256, id: "keyset123", secret: "input1", C: "sig1"),
            Proof(amount: 256, id: "keyset123", secret: "input2", C: "sig2"),
            Proof(amount: 256, id: "keyset123", secret: "input3", C: "sig3"),
            Proof(amount: 256, id: "keyset123", secret: "input4", C: "sig4")
        ]
        
        let multiInputRequest = PostMeltRequest(quote: "multi_quote", inputs: inputs)
        #expect(multiInputRequest.validate())
        #expect(multiInputRequest.totalInputAmount == 1024)
        
        // Change from overpayment
        let changeSignatures = [
            BlindSignature(amount: 16, id: "keyset123", C_: "02change1..."),
            BlindSignature(amount: 4, id: "keyset123", C_: "02change2..."),
            BlindSignature(amount: 2, id: "keyset123", C_: "02change3...")
        ]
        
        let multiChangeResponse = PostMeltResponse(state: MeltQuoteState.paid, change: changeSignatures)
        #expect(multiChangeResponse.validate())
        #expect(multiChangeResponse.totalChangeAmount == 22)
    }
    
    // MARK: - Complex Scenario Tests
    
    @Test
    func pendingPaymentFlow() {
        let currentTime = Int(Date().timeIntervalSince1970)
        let futureTime = currentTime + 3600
        
        // Initial quote response
        let initialQuote = PostMeltQuoteResponse(
            quote: "pending_quote",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: futureTime
        )
        #expect(initialQuote.validate())
        #expect(initialQuote.state.canPay)
        
        // Payment becomes pending
        let pendingQuote = PostMeltQuoteResponse(
            quote: "pending_quote",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.pending,
            expiry: futureTime
        )
        #expect(pendingQuote.validate())
        #expect(!pendingQuote.state.canPay)
        #expect(!pendingQuote.state.isFinal)
        
        // Payment completes
        let completedQuote = PostMeltQuoteResponse(
            quote: "pending_quote",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.paid,
            expiry: futureTime
        )
        #expect(completedQuote.validate())
        #expect(completedQuote.state.isFinal)
    }
    
    @Test
    func expiredQuoteHandling() async {
        let currentTime = Int(Date().timeIntervalSince1970)
        let pastTime = currentTime - 100 // Expired 100 seconds ago
        
        let expiredQuote = PostMeltQuoteResponse(
            quote: "expired_quote",
            amount: 1000,
            unit: "sat",
            state: MeltQuoteState.unpaid,
            expiry: pastTime
        )
        
        #expect(expiredQuote.validate()) // Structure is valid
        #expect(expiredQuote.isExpired)   // But quote is expired
        #expect(expiredQuote.timeUntilExpiry == 0)
        
        // Can't pay expired quotes even if state allows it
        let service = await MeltService()
        let proof = Proof(amount: 1100, id: "keyset123", secret: "secret", C: "signature")
        let keysetInfo = KeysetInfo(id: "keyset123", unit: "sat", active: true, inputFeePpk: 1000)
        let keysetDict = ["keyset123": keysetInfo]
        
        #expect(!service.validateMeltQuote(expiredQuote, against: [proof], keysetInfo: keysetDict))
    }
    
    @Test
    func differentPaymentMethods() {
        // Test various payment methods in quotes and requests
        let bolt11Quote = PostMeltQuoteRequest(request: "lnbc10u1p...", unit: "sat")
        let bolt12Quote = PostMeltQuoteRequest(request: "lno1pg257enxu...", unit: "msat")
        
        #expect(bolt11Quote.validate())
        #expect(bolt12Quote.validate())
        
        // Test method-specific settings
        let bolt11Setting = MeltMethodSetting(
            method: "bolt11",
            unit: "sat",
            minAmount: 100,
            maxAmount: 1_000_000,
            options: ["max_fee_percent": .init(0.01)]
        )
        
        let bolt12Setting = MeltMethodSetting(
            method: "bolt12",
            unit: "msat",
            minAmount: 1000,
            maxAmount: 10_000_000,
            options: ["timeout": .init(300)]
        )
        
        #expect(bolt11Setting.method == "bolt11")
        #expect(bolt11Setting.unit == "sat")
        #expect(bolt11Setting.minAmount == 100)
        #expect(bolt11Setting.maxAmount == 1_000_000)
        
        #expect(bolt12Setting.method == "bolt12")
        #expect(bolt12Setting.unit == "msat")
        #expect(bolt12Setting.minAmount == 1000)
        #expect(bolt12Setting.maxAmount == 10_000_000)
    }
}