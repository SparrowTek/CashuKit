//
//  NUT18Tests.swift
//  CashuKitTests
//
//  Tests for NUT-18: Payment Requests
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-18 Tests")
struct NUT18Tests {
    
    // MARK: - Payment Request Tests
    
    @Test("PaymentRequest basic creation")
    func testPaymentRequestCreation() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            s: true,
            m: ["https://mint.example.com"],
            d: "Payment for coffee",
            t: [Transport(t: "post", a: "https://example.com/payment")],
            nut10: NUT10Option(kind: "P2PK", data: "pubkey123")
        )
        
        #expect(request.paymentId == "payment-123")
        #expect(request.amount == 1000)
        #expect(request.unit == "sat")
        #expect(request.isSingleUse == true)
        #expect(request.mints?.first == "https://mint.example.com")
        #expect(request.description == "Payment for coffee")
        #expect(request.transports?.count == 1)
        #expect(request.lockingCondition?.kind == "P2PK")
    }
    
    @Test("PaymentRequest validation - amount without unit")
    func testPaymentRequestValidationAmountWithoutUnit() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: nil // Missing unit
        )
        
        do {
            try request.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequest validation - negative amount")
    func testPaymentRequestValidationNegativeAmount() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: -100,
            u: "sat"
        )
        
        do {
            try request.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequest validation - invalid mint URL")
    func testPaymentRequestValidationInvalidMintURL() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            m: ["not-a-valid-url"]
        )
        
        do {
            try request.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequest validation - valid request")
    func testPaymentRequestValidationValid() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            s: true,
            m: ["https://mint.example.com"],
            d: "Payment for coffee"
        )
        
        try request.validate()
        #expect(Bool(true)) // Should not throw
    }
    
    // MARK: - Transport Tests
    
    @Test("Transport types")
    func testTransportTypes() {
        #expect(TransportType.nostr.rawValue == "nostr")
        #expect(TransportType.post.rawValue == "post")
        #expect(TransportType.unknown.rawValue == "unknown")
        
        #expect(TransportType.nostr.description == "Nostr Direct Message")
        #expect(TransportType.post.description == "HTTP POST")
        #expect(TransportType.unknown.description == "Unknown Transport")
    }
    
    @Test("Transport creation and validation - Nostr")
    func testTransportNostr() throws {
        let transport = Transport(
            t: "nostr",
            a: "nprofile1qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hsz...",
            g: [["n", "17"]]
        )
        
        #expect(transport.type == .nostr)
        #expect(transport.target.hasPrefix("nprofile1"))
        #expect(transport.tags?.first?.first == "n")
        
        try transport.validate()
    }
    
    @Test("Transport creation and validation - POST")
    func testTransportPost() throws {
        let transport = Transport(
            t: "post",
            a: "https://example.com/payment"
        )
        
        #expect(transport.type == .post)
        #expect(transport.target == "https://example.com/payment")
        #expect(transport.tags == nil)
        
        try transport.validate()
    }
    
    @Test("Transport validation - invalid Nostr profile")
    func testTransportValidationInvalidNostrProfile() throws {
        let transport = Transport(
            t: "nostr",
            a: "invalid-nprofile",
            g: [["n", "17"]]
        )
        
        do {
            try transport.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Transport validation - invalid POST URL")
    func testTransportValidationInvalidPostURL() throws {
        let transport = Transport(
            t: "post",
            a: "not-a-valid-url"
        )
        
        do {
            try transport.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("Transport validation - unknown transport type")
    func testTransportValidationUnknownType() throws {
        let transport = Transport(
            t: "unknown-transport",
            a: "some-target"
        )
        
        // Unknown transport types should be allowed
        try transport.validate()
        #expect(transport.type == .unknown)
    }
    
    // MARK: - NUT-10 Option Tests
    
    @Test("NUT10Option creation")
    func testNUT10OptionCreation() {
        let option = NUT10Option(
            kind: "P2PK",
            data: "pubkey123",
            tags: [["exp", "1234567890"]]
        )
        
        #expect(option.kind == "P2PK")
        #expect(option.data == "pubkey123")
        #expect(option.tags?.first?.first == "exp")
        #expect(option.lockingType == .p2pk)
    }
    
    @Test("LockingConditionType enum")
    func testLockingConditionType() {
        #expect(LockingConditionType.p2pk.rawValue == "P2PK")
        #expect(LockingConditionType.htlc.rawValue == "HTLC")
        #expect(LockingConditionType.unknown.rawValue == "unknown")
        
        #expect(LockingConditionType.p2pk.description == "Pay to Public Key")
        #expect(LockingConditionType.htlc.description == "Hash Time Lock Contract")
        #expect(LockingConditionType.unknown.description == "Unknown Locking Condition")
    }
    
    // MARK: - Payment Payload Tests
    
    @Test("PaymentRequestPayload creation and validation")
    func testPaymentRequestPayloadCreation() throws {
        let proofs = [
            Proof(amount: 500, id: "test", secret: "secret1", C: "C1"),
            Proof(amount: 500, id: "test", secret: "secret2", C: "C2")
        ]
        
        let payload = PaymentRequestPayload(
            id: "payment-123",
            memo: "Thanks for the coffee",
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: proofs
        )
        
        #expect(payload.id == "payment-123")
        #expect(payload.memo == "Thanks for the coffee")
        #expect(payload.mint == "https://mint.example.com")
        #expect(payload.unit == "sat")
        #expect(payload.proofs.count == 2)
        #expect(payload.totalAmount == 1000)
        
        try payload.validate()
    }
    
    @Test("PaymentRequestPayload validation - invalid mint URL")
    func testPaymentRequestPayloadValidationInvalidMintURL() throws {
        let proofs = [Proof(amount: 1000, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            mint: "not-a-valid-url",
            unit: "sat",
            proofs: proofs
        )
        
        do {
            try payload.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequestPayload validation - empty unit")
    func testPaymentRequestPayloadValidationEmptyUnit() throws {
        let proofs = [Proof(amount: 1000, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            mint: "https://mint.example.com",
            unit: "",
            proofs: proofs
        )
        
        do {
            try payload.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequestPayload validation - empty proofs")
    func testPaymentRequestPayloadValidationEmptyProofs() throws {
        let payload = PaymentRequestPayload(
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: []
        )
        
        do {
            try payload.validate()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequestPayload matches request")
    func testPaymentRequestPayloadMatchesRequest() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            m: ["https://mint.example.com"]
        )
        
        let proofs = [Proof(amount: 1000, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            id: "payment-123",
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: proofs
        )
        
        #expect(payload.matches(request) == true)
    }
    
    @Test("PaymentRequestPayload doesn't match request - wrong amount")
    func testPaymentRequestPayloadDoesntMatchRequestWrongAmount() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat"
        )
        
        let proofs = [Proof(amount: 500, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            id: "payment-123",
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: proofs
        )
        
        #expect(payload.matches(request) == false)
    }
    
    @Test("PaymentRequestPayload doesn't match request - wrong unit")
    func testPaymentRequestPayloadDoesntMatchRequestWrongUnit() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "usd"
        )
        
        let proofs = [Proof(amount: 1000, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            id: "payment-123",
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: proofs
        )
        
        #expect(payload.matches(request) == false)
    }
    
    @Test("PaymentRequestPayload doesn't match request - wrong mint")
    func testPaymentRequestPayloadDoesntMatchRequestWrongMint() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            m: ["https://other-mint.example.com"]
        )
        
        let proofs = [Proof(amount: 1000, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            id: "payment-123",
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: proofs
        )
        
        #expect(payload.matches(request) == false)
    }
    
    // MARK: - Payment Request Encoding/Decoding Tests
    
    @Test("PaymentRequestEncoder encode/decode")
    func testPaymentRequestEncoderEncodeDecode() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            s: true,
            m: ["https://mint.example.com"],
            d: "Payment for coffee"
        )
        
        let encoded = try PaymentRequestEncoder.encode(request)
        #expect(encoded.hasPrefix("creqA"))
        
        let decoded = try PaymentRequestEncoder.decode(encoded)
        #expect(decoded.paymentId == request.paymentId)
        #expect(decoded.amount == request.amount)
        #expect(decoded.unit == request.unit)
        #expect(decoded.isSingleUse == request.isSingleUse)
        #expect(decoded.mints == request.mints)
        #expect(decoded.description == request.description)
    }
    
    @Test("PaymentRequestEncoder decode invalid format")
    func testPaymentRequestEncoderDecodeInvalidFormat() throws {
        let invalidEncoded = "invalid-format"
        
        do {
            let _ = try PaymentRequestEncoder.decode(invalidEncoded)
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    @Test("PaymentRequestEncoder encode invalid request")
    func testPaymentRequestEncoderEncodeInvalidRequest() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: nil // Missing unit
        )
        
        do {
            let _ = try PaymentRequestEncoder.encode(request)
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - Payment Request Builder Tests
    
    @Test("PaymentRequestBuilder basic usage")
    func testPaymentRequestBuilderBasicUsage() throws {
        let request = try PaymentRequestBuilder()
            .withPaymentId("payment-123")
            .withAmount(1000, unit: "sat")
            .withDescription("Payment for coffee")
            .withSingleUse(true)
            .withMints(["https://mint.example.com"])
            .build()
        
        #expect(request.paymentId == "payment-123")
        #expect(request.amount == 1000)
        #expect(request.unit == "sat")
        #expect(request.description == "Payment for coffee")
        #expect(request.isSingleUse == true)
        #expect(request.mints?.first == "https://mint.example.com")
    }
    
    @Test("PaymentRequestBuilder with transports")
    func testPaymentRequestBuilderWithTransports() throws {
        let request = try PaymentRequestBuilder()
            .withPaymentId("payment-123")
            .withAmount(1000, unit: "sat")
            .withNostrTransport(nprofile: "nprofile1qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hsz...", nips: ["17"])
            .withPostTransport(url: "https://example.com/payment")
            .build()
        
        #expect(request.transports?.count == 2)
        #expect(request.transports?.first?.type == .nostr)
        #expect(request.transports?.last?.type == .post)
    }
    
    @Test("PaymentRequestBuilder with locking condition")
    func testPaymentRequestBuilderWithLockingCondition() throws {
        let condition = NUT10Option(kind: "P2PK", data: "pubkey123")
        let request = try PaymentRequestBuilder()
            .withPaymentId("payment-123")
            .withAmount(1000, unit: "sat")
            .withLockingCondition(condition)
            .build()
        
        #expect(request.lockingCondition?.kind == "P2PK")
        #expect(request.lockingCondition?.data == "pubkey123")
    }
    
    @Test("PaymentRequestBuilder validation failure")
    func testPaymentRequestBuilderValidationFailure() throws {
        do {
            let _ = try PaymentRequestBuilder()
                .withAmount(1000, unit: "sat")
                .withMints(["not-a-valid-url"])
                .build()
            #expect(Bool(false), "Should have thrown validation error")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - Base64 URL-Safe Encoding Tests
    
    @Test("Base64 URL-safe encoding")
    func testBase64URLSafeEncoding() {
        let data = Data("Hello, World!".utf8)
        let encoded = data.base64URLSafeEncodedString()
        
        // Should not contain +, /, or = characters
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
        
        // Should be decodable
        let decoded = Data(base64URLSafeEncoded: encoded)
        #expect(decoded != nil)
        #expect(String(data: decoded!, encoding: .utf8) == "Hello, World!")
    }
    
    @Test("Base64 URL-safe decoding")
    func testBase64URLSafeDecoding() {
        let originalData = Data("Test data for encoding".utf8)
        let encoded = originalData.base64URLSafeEncodedString()
        let decoded = Data(base64URLSafeEncoded: encoded)
        
        #expect(decoded == originalData)
    }
    
    @Test("Base64 URL-safe decoding with padding")
    func testBase64URLSafeDecodingWithPadding() {
        // Test various padding scenarios
        let testCases = [
            "SGVsbG8",      // No padding needed
            "SGVsbG9X",     // 1 padding character needed
            "SGVsbG9Xb3I",  // 2 padding characters needed
            "SGVsbG9Xb3Js"  // 3 padding characters needed (max)
        ]
        
        for testCase in testCases {
            let decoded = Data(base64URLSafeEncoded: testCase)
            #expect(decoded != nil)
        }
    }
    
    // MARK: - Integration Tests
    
    @Test("Full payment request workflow")
    func testFullPaymentRequestWorkflow() throws {
        // Create a payment request
        let request = try PaymentRequestBuilder()
            .withPaymentId("payment-123")
            .withAmount(1000, unit: "sat")
            .withDescription("Payment for coffee")
            .withSingleUse(true)
            .withMints(["https://mint.example.com"])
            .withPostTransport(url: "https://example.com/payment")
            .build()
        
        // Encode the request
        let encoded = try PaymentRequestEncoder.encode(request)
        #expect(encoded.hasPrefix("creqA"))
        
        // Decode the request
        let decoded = try PaymentRequestEncoder.decode(encoded)
        #expect(decoded.paymentId == request.paymentId)
        #expect(decoded.amount == request.amount)
        
        // Create a payment payload
        let proofs = [Proof(amount: 1000, id: "test", secret: "secret", C: "C")]
        let payload = PaymentRequestPayload(
            id: request.paymentId,
            memo: "Thanks!",
            mint: "https://mint.example.com",
            unit: "sat",
            proofs: proofs
        )
        
        // Validate payload matches request
        #expect(payload.matches(decoded) == true)
        
        // Validate payload
        try payload.validate()
    }
    
    @Test("Payment request with multiple transports")
    func testPaymentRequestWithMultipleTransports() throws {
        let request = try PaymentRequestBuilder()
            .withPaymentId("payment-123")
            .withAmount(1000, unit: "sat")
            .withNostrTransport(nprofile: "nprofile1qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hsz...", nips: ["17"])
            .withPostTransport(url: "https://example.com/payment")
            .build()
        
        #expect(request.transports?.count == 2)
        
        let encoded = try PaymentRequestEncoder.encode(request)
        let decoded = try PaymentRequestEncoder.decode(encoded)
        
        #expect(decoded.transports?.count == 2)
        #expect(decoded.transports?.contains { $0.type == .nostr } == true)
        #expect(decoded.transports?.contains { $0.type == .post } == true)
    }
    
    @Test("Payment request with NUT-10 locking condition")
    func testPaymentRequestWithNUT10LockingCondition() throws {
        let condition = NUT10Option(
            kind: "P2PK",
            data: "pubkey123",
            tags: [["exp", "1234567890"]]
        )
        
        let request = try PaymentRequestBuilder()
            .withPaymentId("payment-123")
            .withAmount(1000, unit: "sat")
            .withLockingCondition(condition)
            .build()
        
        #expect(request.lockingCondition?.kind == "P2PK")
        #expect(request.lockingCondition?.data == "pubkey123")
        #expect(request.lockingCondition?.tags?.first?.first == "exp")
        
        let encoded = try PaymentRequestEncoder.encode(request)
        let decoded = try PaymentRequestEncoder.decode(encoded)
        
        #expect(decoded.lockingCondition?.kind == "P2PK")
        #expect(decoded.lockingCondition?.data == "pubkey123")
        #expect(decoded.lockingCondition?.lockingType == .p2pk)
    }
    
    @Test("Minimal payment request")
    func testMinimalPaymentRequest() throws {
        let request = PaymentRequest()
        
        // Minimal request should be valid
        try request.validate()
        
        let encoded = try PaymentRequestEncoder.encode(request)
        let decoded = try PaymentRequestEncoder.decode(encoded)
        
        #expect(decoded.paymentId == nil)
        #expect(decoded.amount == nil)
        #expect(decoded.unit == nil)
        #expect(decoded.mints == nil)
        #expect(decoded.transports == nil)
    }
    
    @Test("Payment request JSON serialization")
    func testPaymentRequestJSONSerialization() throws {
        let request = PaymentRequest(
            i: "payment-123",
            a: 1000,
            u: "sat",
            s: true,
            m: ["https://mint.example.com"],
            d: "Payment for coffee"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PaymentRequest.self, from: data)
        
        #expect(decoded.paymentId == request.paymentId)
        #expect(decoded.amount == request.amount)
        #expect(decoded.unit == request.unit)
        #expect(decoded.isSingleUse == request.isSingleUse)
        #expect(decoded.mints == request.mints)
        #expect(decoded.description == request.description)
    }
}