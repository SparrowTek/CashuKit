//
//  NUT17Tests.swift
//  CashuKitTests
//
//  Tests for NUT-17: WebSockets
//

import Testing
@testable import CashuKit
import Foundation

@Suite("NUT-17 Tests")
struct NUT17Tests {
    
    @Test("JSON-RPC types")
    func testJSONRPCTypes() {
        #expect(WsRequestMethod.subscribe.rawValue == "subscribe")
        #expect(WsRequestMethod.unsubscribe.rawValue == "unsubscribe")
        
        #expect(SubscriptionKind.bolt11MeltQuote.rawValue == "bolt11_melt_quote")
        #expect(SubscriptionKind.bolt11MintQuote.rawValue == "bolt11_mint_quote")
        #expect(SubscriptionKind.proofState.rawValue == "proof_state")
    }
    
    @Test("WsRequest creation - subscribe")
    func testWsRequestSubscribe() throws {
        let request = try WsRequest.subscribe(
            kind: .proofState,
            subId: "test-sub-id",
            filters: ["filter1", "filter2"],
            id: 1
        )
        
        #expect(request.jsonrpc == "2.0")
        #expect(request.method == .subscribe)
        #expect(request.id == 1)
        
        // Decode params to verify
        let paramsData = request.params.data(using: .utf8)!
        let params = try JSONDecoder().decode(WsSubscribeParams.self, from: paramsData)
        
        #expect(params.kind == .proofState)
        #expect(params.subId == "test-sub-id")
        #expect(params.filters == ["filter1", "filter2"])
    }
    
    @Test("WsRequest creation - unsubscribe")
    func testWsRequestUnsubscribe() throws {
        let request = try WsRequest.unsubscribe(
            subId: "test-sub-id",
            id: 2
        )
        
        #expect(request.jsonrpc == "2.0")
        #expect(request.method == .unsubscribe)
        #expect(request.id == 2)
        
        // Decode params to verify
        let paramsData = request.params.data(using: .utf8)!
        let params = try JSONDecoder().decode(WsUnsubscribeParams.self, from: paramsData)
        
        #expect(params.subId == "test-sub-id")
    }
    
    @Test("WsResponse success")
    func testWsResponseSuccess() {
        let response = WsResponse(
            result: WsResponseResult(status: "OK", subId: "test-sub-id"),
            id: 1
        )
        
        #expect(response.isSuccess == true)
        #expect(response.result?.status == "OK")
        #expect(response.result?.subId == "test-sub-id")
        #expect(response.error == nil)
    }
    
    @Test("WsResponse error")
    func testWsResponseError() {
        let response = WsResponse(
            error: WsError(code: -32601, message: "Method not found"),
            id: 1
        )
        
        #expect(response.isSuccess == false)
        #expect(response.result == nil)
        #expect(response.error?.code == -32601)
        #expect(response.error?.message == "Method not found")
    }
    
    @Test("WsNotification structure")
    func testWsNotification() {
        let payload = AnyCodable(anyValue: ["state": "SPENT", "Y": "test-y-value"])!
        let notification = WsNotification(
            params: WsNotificationParams(
                subId: "test-sub-id",
                payload: payload
            )
        )
        
        #expect(notification.jsonrpc == "2.0")
        #expect(notification.method == "subscribe")
        #expect(notification.params.subId == "test-sub-id")
        #expect(notification.params.payload.dictionaryValue != nil)
    }
    
    @Test("WsMessage decoding - response")
    func testWsMessageDecodingResponse() throws {
        let response = WsResponse(
            result: WsResponseResult(status: "OK", subId: "test-sub-id"),
            id: 1
        )
        
        let data = try JSONEncoder().encode(response)
        let message = try WsMessage.decode(from: data)
        
        switch message {
        case .response(let decoded):
            #expect(decoded.isSuccess == true)
            #expect(decoded.result?.subId == "test-sub-id")
        default:
            #expect(Bool(false), "Expected response message")
        }
    }
    
    @Test("WsMessage decoding - notification")
    func testWsMessageDecodingNotification() throws {
        let payload = AnyCodable(anyValue: ["state": "SPENT"])!
        let notification = WsNotification(
            params: WsNotificationParams(
                subId: "test-sub-id",
                payload: payload
            )
        )
        
        let data = try JSONEncoder().encode(notification)
        let message = try WsMessage.decode(from: data)
        
        switch message {
        case .notification(let decoded):
            #expect(decoded.params.subId == "test-sub-id")
        default:
            #expect(Bool(false), "Expected notification message")
        }
    }
    
    @Test("NotificationPayloadDecoder - ProofState")
    func testNotificationPayloadDecoderProofState() throws {
        let proofStateDict: [String: Any] = [
            "Y": "02e208f9a78cd523444aadf854a4e91281d20f67a923d345239c37f14e137c7c3d",
            "state": "SPENT"
        ]
        
        guard let payload = AnyCodable(anyValue: proofStateDict) else {
            #expect(Bool(false), "Failed to create AnyCodable")
            return
        }
        let proofStateInfo = try NotificationPayloadDecoder.decodeProofState(from: payload)
        
        #expect(proofStateInfo.Y == "02e208f9a78cd523444aadf854a4e91281d20f67a923d345239c37f14e137c7c3d")
        #expect(proofStateInfo.state == .spent)
        #expect(proofStateInfo.witness == nil)
    }
    
    @Test("WsSubscription")
    func testWsSubscription() {
        let subscription = WsSubscription(
            id: "test-sub-id",
            kind: .proofState,
            filters: ["filter1", "filter2"]
        )
        
        #expect(subscription.id == "test-sub-id")
        #expect(subscription.kind == .proofState)
        #expect(subscription.filters == ["filter1", "filter2"])
        #expect(subscription.createdAt.timeIntervalSinceNow < 1) // Recently created
    }
    
    @Test("NUT17 settings parsing")
    func testNUT17SettingsParsing() {
        let settings = NUT17Settings(
            supported: [
                NUT17MethodSupport(
                    method: "bolt11",
                    unit: "sat",
                    commands: ["bolt11_mint_quote", "bolt11_melt_quote", "proof_state"]
                )
            ]
        )
        
        let support = settings.supported.first!
        #expect(support.method == "bolt11")
        #expect(support.unit == "sat")
        #expect(support.supports(.bolt11MintQuote) == true)
        #expect(support.supports(.bolt11MeltQuote) == true)
        #expect(support.supports(.proofState) == true)
    }
    
    @Test("MintInfo NUT-17 support")
    func testMintInfoNUT17Support() {
        let nut17Value = NutValue.dictionary([
            "supported": AnyCodable(anyValue: [
                [
                    "method": "bolt11",
                    "unit": "sat",
                    "commands": ["bolt11_mint_quote", "bolt11_melt_quote", "proof_state"]
                ]
            ])!
        ])
        
        let mintInfo = MintInfo(
            name: "Test Mint",
            pubkey: "pubkey",
            version: "1.0",
            nuts: ["17": nut17Value]
        )
        
        #expect(mintInfo.supportsWebSockets == true)
        
        let settings = mintInfo.getNUT17Settings()
        #expect(settings != nil)
        #expect(settings?.supported.count == 1)
        
        #expect(mintInfo.supportsWebSocketSubscription(
            kind: .proofState,
            method: "bolt11",
            unit: "sat"
        ) == true)
        
        #expect(mintInfo.supportsWebSocketSubscription(
            kind: .proofState,
            method: "bolt11",
            unit: "usd"
        ) == false)
    }
    
    @Test("WebSocket URL creation")
    func testWebSocketURLCreation() async throws {
        // Test HTTPS to WSS conversion
        let httpsWallet = await CashuWallet(mintURL: "https://mint.example.com")
        let _ = try await httpsWallet.createWebSocketClient()
        // Can't access private URL property, but creation should succeed
        
        // Test HTTP to WS conversion
        let httpWallet = await CashuWallet(mintURL: "http://mint.example.com")
        let _ = try await httpWallet.createWebSocketClient()
        // Can't access private URL property, but creation should succeed
        
        #expect(Bool(true)) // If we reach here, clients were created successfully
    }
    
    @Test("JSON-RPC serialization")
    func testJSONRPCSerialization() throws {
        // Test request serialization
        let request = WsRequest(
            method: .subscribe,
            params: "{\"kind\":\"proof_state\",\"subId\":\"123\",\"filters\":[]}",
            id: 1
        )
        
        let requestData = try JSONEncoder().encode(request)
        let requestJSON = String(data: requestData, encoding: .utf8)!
        
        #expect(requestJSON.contains("\"jsonrpc\":\"2.0\""))
        #expect(requestJSON.contains("\"method\":\"subscribe\""))
        #expect(requestJSON.contains("\"id\":1"))
        
        // Test response serialization
        let response = WsResponse(
            result: WsResponseResult(status: "OK", subId: "123"),
            id: 1
        )
        
        let responseData = try JSONEncoder().encode(response)
        let responseJSON = String(data: responseData, encoding: .utf8)!
        
        #expect(responseJSON.contains("\"jsonrpc\":\"2.0\""))
        #expect(responseJSON.contains("\"status\":\"OK\""))
        #expect(responseJSON.contains("\"subId\":\"123\""))
    }
    
    @Test("Subscribe params validation")
    func testSubscribeParamsValidation() {
        let params = WsSubscribeParams(
            kind: .bolt11MintQuote,
            subId: "unique-id-123",
            filters: ["quote1", "quote2", "quote3"]
        )
        
        #expect(params.kind == .bolt11MintQuote)
        #expect(params.subId == "unique-id-123")
        #expect(params.filters.count == 3)
        #expect(params.filters.contains("quote2"))
    }
    
    @Test("Multiple subscription kinds")
    func testMultipleSubscriptionKinds() {
        let kinds = SubscriptionKind.allCases
        #expect(kinds.count == 3)
        
        for kind in kinds {
            #expect(!kind.rawValue.isEmpty)
            #expect(!kind.description.isEmpty)
        }
    }
    
    @Test("Error handling")
    func testErrorHandling() {
        let error = WsError(code: -32700, message: "Parse error")
        
        #expect(error.code == -32700)
        #expect(error.message == "Parse error")
        
        // Test as Swift Error
        let swiftError: Error = error
        #expect(swiftError is WsError)
    }
    
    @Test("Notification payload with complex data")
    func testComplexNotificationPayload() throws {
        let mintQuoteDict: [String: Any] = [
            "quote": "quote-id-123",
            "amount": 1000,
            "unit": "sat",
            "state": "PAID",
            "expiry": 1234567890
        ]
        
        let payload = AnyCodable(anyValue: mintQuoteDict)!
        let notification = WsNotification(
            params: WsNotificationParams(
                subId: "sub-123",
                payload: payload
            )
        )
        
        // Serialize and deserialize
        let data = try JSONEncoder().encode(notification)
        let decoded = try JSONDecoder().decode(WsNotification.self, from: data)
        
        #expect(decoded.params.subId == "sub-123")
        #expect(decoded.params.payload.dictionaryValue?["quote"] as? String == "quote-id-123")
        #expect(decoded.params.payload.dictionaryValue?["amount"] as? Int == 1000)
    }
    
    @available(iOS 13.0, macOS 10.15, *)
    @Test("WebSocketClient initialization")
    func testWebSocketClientInitialization() async throws {
        let url = URL(string: "wss://mint.example.com/v1/ws")!
        let client = WebSocketClient(url: url)
        
        // Client should be created successfully
        #expect(Bool(true))
        
        // Disconnect should work even without connection
        await client.disconnect()
    }
}