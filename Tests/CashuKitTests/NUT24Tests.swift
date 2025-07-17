//
//  NUT24Tests.swift
//  CashuKit
//
//  Tests for NUT-24: HTTP 402 Payment Required
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-24: HTTP 402 Payment Required Tests")
struct NUT24Tests {
    
    // MARK: - Payment Request Tests
    
    @Test("HTTP402PaymentRequest initialization and encoding")
    func testHTTP402PaymentRequest() throws {
        let request = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint1.example.com", "https://mint2.example.com"],
            nut10: nil
        )
        
        #expect(request.a == 100)
        #expect(request.amount == 100)
        #expect(request.u == "sat")
        #expect(request.unit == "sat")
        #expect(request.m.count == 2)
        #expect(request.mints.contains("https://mint1.example.com"))
        #expect(request.nut10 == nil)
        
        // Test encoding
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(HTTP402PaymentRequest.self, from: encoded)
        
        #expect(decoded.a == request.a)
        #expect(decoded.u == request.u)
        #expect(decoded.m == request.m)
    }
    
    @Test("HTTP402PaymentRequest with NUT-10 condition")
    func testHTTP402PaymentRequestWithNUT10() throws {
        let nut10Option = NUT10Option(
            kind: "P2PK",
            data: "02abc123...",
            tags: nil
        )
        
        let request = HTTP402PaymentRequest(
            amount: 50,
            unit: "usd",
            mints: ["https://mint.example.com"],
            nut10: nut10Option
        )
        
        #expect(request.nut10 != nil)
        #expect(request.nut10?.kind == "P2PK")
        #expect(request.nut10?.lockingType == .p2pk)
        
        // Test encoding with NUT-10
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        
        #expect(json?["a"] as? Int == 50)
        #expect(json?["u"] as? String == "usd")
        #expect(json?["nut10"] != nil)
    }
    
    // MARK: - HTTP Response Tests
    
    @Test("HTTP402Response initialization")
    func testHTTP402Response() throws {
        let paymentRequest = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let requestData = try JSONEncoder().encode(paymentRequest)
        let base64Request = requestData.base64EncodedString()
        
        let response = HTTP402Response(paymentRequest: base64Request)
        
        #expect(response.statusCode == 402)
        #expect(response.paymentRequest == base64Request)
        #expect(response.decodedRequest != nil)
        #expect(response.decodedRequest?.amount == 100)
        #expect(response.decodedRequest?.unit == "sat")
    }
    
    @Test("HTTP402Response with invalid encoding")
    func testHTTP402ResponseInvalidEncoding() {
        let response = HTTP402Response(paymentRequest: "invalid-base64")
        
        #expect(response.statusCode == 402)
        #expect(response.decodedRequest == nil)
    }
    
    // MARK: - HTTP Client Tests
    
    @Test("Parse payment required from headers")
    func testParsePaymentRequired() throws {
        let paymentRequest = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let requestData = try JSONEncoder().encode(paymentRequest)
        let base64Request = requestData.base64EncodedString()
        
        let headers = [CashuHTTPHeader.xCashu: base64Request]
        let parsed = CashuHTTPClient.parsePaymentRequired(headers: headers)
        
        #expect(parsed != nil)
        #expect(parsed?.decodedRequest?.amount == 100)
    }
    
    @Test("Parse payment required with missing header")
    func testParsePaymentRequiredMissingHeader() {
        let headers = ["Content-Type": "application/json"]
        let parsed = CashuHTTPClient.parsePaymentRequired(headers: headers)
        
        #expect(parsed == nil)
    }
    
    @Test("Create payment headers")
    func testCreatePaymentHeaders() {
        let proof = Proof(
            amount: 100,
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let tokenEntry = TokenEntry(
            mint: "https://mint.example.com",
            proofs: [proof]
        )
        
        let token = CashuToken(
            token: [tokenEntry],
            unit: "sat"
        )
        
        let headers = CashuHTTPClient.createPaymentHeaders(token: token)
        
        #expect(headers[CashuHTTPHeader.xCashu] != nil)
        #expect(headers[CashuHTTPHeader.xCashu]?.starts(with: "cashuB") == true)
    }
    
    // MARK: - Payment Validation Tests
    
    @Test("Validate token for payment - success")
    func testValidateTokenSuccess() {
        let paymentRequest = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let proof = Proof(
            amount: 150,
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let tokenEntry = TokenEntry(
            mint: "https://mint.example.com",
            proofs: [proof]
        )
        
        let token = CashuToken(
            token: [tokenEntry],
            unit: "sat"
        )
        
        let result = CashuHTTPClient.validateTokenForPayment(
            token: token,
            paymentRequest: paymentRequest
        )
        
        if case .success = result {
            #expect(true)
        } else {
            #expect(Bool(false), "Validation should succeed")
        }
    }
    
    @Test("Validate token - mint not accepted")
    func testValidateTokenMintNotAccepted() {
        let paymentRequest = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint1.example.com"],
            nut10: nil
        )
        
        let proof = Proof(
            amount: 150,
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let tokenEntry = TokenEntry(
            mint: "https://mint2.example.com", // Different mint
            proofs: [proof]
        )
        
        let token = CashuToken(
            token: [tokenEntry],
            unit: "sat"
        )
        
        let result = CashuHTTPClient.validateTokenForPayment(
            token: token,
            paymentRequest: paymentRequest
        )
        
        if case .failure(let error) = result {
            #expect(error == .mintNotAccepted)
        } else {
            #expect(Bool(false), "Validation should fail with mintNotAccepted")
        }
    }
    
    @Test("Validate token - incorrect unit")
    func testValidateTokenIncorrectUnit() {
        let paymentRequest = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let proof = Proof(
            amount: 150,
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let tokenEntry = TokenEntry(
            mint: "https://mint.example.com",
            proofs: [proof]
        )
        
        let token = CashuToken(
            token: [tokenEntry],
            unit: "usd" // Different unit
        )
        
        let result = CashuHTTPClient.validateTokenForPayment(
            token: token,
            paymentRequest: paymentRequest
        )
        
        if case .failure(let error) = result {
            #expect(error == .incorrectUnit)
        } else {
            #expect(Bool(false), "Validation should fail with incorrectUnit")
        }
    }
    
    @Test("Validate token - insufficient amount")
    func testValidateTokenInsufficientAmount() {
        let paymentRequest = HTTP402PaymentRequest(
            amount: 100,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let proof = Proof(
            amount: 50, // Less than required
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let tokenEntry = TokenEntry(
            mint: "https://mint.example.com",
            proofs: [proof]
        )
        
        let token = CashuToken(
            token: [tokenEntry],
            unit: "sat"
        )
        
        let result = CashuHTTPClient.validateTokenForPayment(
            token: token,
            paymentRequest: paymentRequest
        )
        
        if case .failure(let error) = result {
            #expect(error == .insufficientAmount)
        } else {
            #expect(Bool(false), "Validation should fail with insufficientAmount")
        }
    }
    
    // MARK: - Error Tests
    
    @Test("PaymentValidationError descriptions")
    func testPaymentValidationErrorDescriptions() {
        let errors: [PaymentValidationError] = [
            .mintNotAccepted,
            .incorrectUnit,
            .insufficientAmount,
            .insufficientLockingConditions
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Token Total Amount Tests
    
    @Test("CashuToken total amount calculation")
    func testCashuTokenTotalAmount() {
        let proofs1 = [
            Proof(amount: 10, id: "keyset1", secret: "s1", C: "c1"),
            Proof(amount: 20, id: "keyset1", secret: "s2", C: "c2")
        ]
        
        let proofs2 = [
            Proof(amount: 30, id: "keyset2", secret: "s3", C: "c3"),
            Proof(amount: 40, id: "keyset2", secret: "s4", C: "c4")
        ]
        
        let token = CashuToken(
            token: [
                TokenEntry(mint: "https://mint1.com", proofs: proofs1),
                TokenEntry(mint: "https://mint2.com", proofs: proofs2)
            ],
            unit: "sat"
        )
        
        #expect(token.totalAmount == 100) // 10 + 20 + 30 + 40
    }
    
    // MARK: - Payment Flow Tests
    
    @Test("HTTP402PaymentFlow handle payment required")
    func testHTTP402PaymentFlowHandlePaymentRequired() async throws {
        let paymentFlow = HTTP402PaymentFlow()
        
        let paymentRequest = HTTP402PaymentRequest(
            amount: 50,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let requestData = try JSONEncoder().encode(paymentRequest)
        let base64Request = requestData.base64EncodedString()
        let response = HTTP402Response(paymentRequest: base64Request)
        
        let validProof = Proof(
            amount: 100,
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let validToken = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [validProof])],
            unit: "sat"
        )
        
        let invalidToken = CashuToken(
            token: [TokenEntry(mint: "https://wrong-mint.com", proofs: [validProof])],
            unit: "sat"
        )
        
        let availableTokens = [invalidToken, validToken]
        
        let selectedToken = try await paymentFlow.handlePaymentRequired(
            response: response,
            availableTokens: availableTokens
        )
        
        #expect(selectedToken != nil)
        #expect(selectedToken?.token.first?.mint == "https://mint.example.com")
    }
    
    @Test("HTTP402PaymentFlow no suitable token")
    func testHTTP402PaymentFlowNoSuitableToken() async throws {
        let paymentFlow = HTTP402PaymentFlow()
        
        let paymentRequest = HTTP402PaymentRequest(
            amount: 50,
            unit: "sat",
            mints: ["https://mint.example.com"],
            nut10: nil
        )
        
        let requestData = try JSONEncoder().encode(paymentRequest)
        let base64Request = requestData.base64EncodedString()
        let response = HTTP402Response(paymentRequest: base64Request)
        
        let proof = Proof(
            amount: 25, // Not enough
            id: "test-keyset",
            secret: "secret123",
            C: "signature123"
        )
        
        let token = CashuToken(
            token: [TokenEntry(mint: "https://mint.example.com", proofs: [proof])],
            unit: "sat"
        )
        
        let selectedToken = try await paymentFlow.handlePaymentRequired(
            response: response,
            availableTokens: [token]
        )
        
        #expect(selectedToken == nil)
    }
}