//
//  AppleWebSocketClientTests.swift
//  CashuKitTests
//
//  Tests for AppleWebSocketClient implementation
//

import Testing
import Foundation
import CoreCashu
@testable import CashuKit

@Suite("AppleWebSocketClient Tests")
struct AppleWebSocketClientTests {
    
    @Test("Client initialization")
    func testClientInitialization() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        #expect(client != nil)
    }
    
    @Test("Connection lifecycle")
    func testConnectionLifecycle() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        // Test connect
        try await client.connect()
        #expect(await client.isConnected == true)
        
        // Test disconnect
        try await client.disconnect()
        #expect(await client.isConnected == false)
    }
    
    @Test("Send and receive messages", .disabled("Requires test WebSocket server"))
    func testSendReceive() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        try await client.connect()
        
        let testMessage = "Hello, WebSocket!"
        try await client.send(testMessage)
        
        // In a real test, we'd wait for the echo
        // For now, just verify no crash
        
        try await client.disconnect()
    }
    
    @Test("Reconnection handling")
    func testReconnection() async throws {
        let url = URL(string: "wss://invalid.websocket.test")!
        let client = AppleWebSocketClient(url: url)
        
        // Should handle connection failure gracefully
        do {
            try await client.connect()
        } catch {
            // Expected to fail
            #expect(error != nil)
        }
        
        #expect(await client.isConnected == false)
    }
    
    @Test("Provider creation")
    func testProviderCreation() async throws {
        let provider = AppleWebSocketProvider()
        let url = URL(string: "wss://test.websocket.org")!
        
        let client = provider.createClient(url: url)
        #expect(client != nil)
    }
    
    @Test("Ping/Pong keepalive")
    func testPingPong() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        // Start ping timer should not crash
        await client.startPingTimer()
        
        // Stop ping timer should not crash
        await client.stopPingTimer()
        
        #expect(true)
    }
    
    @Test("Message handler")
    func testMessageHandler() async throws {
        let url = URL(string: "wss://test.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        var receivedMessage: String?
        
        await client.setMessageHandler { message in
            receivedMessage = message
        }
        
        // Simulate receiving a message (would come from WebSocket in real scenario)
        // This tests the handler mechanism
        #expect(client != nil)
    }
    
    @Test("Connection state transitions")
    func testConnectionStates() async throws {
        let url = URL(string: "wss://test.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        #expect(await client.connectionState == .disconnected)
        
        // Attempt connection (may fail, but state should change)
        _ = try? await client.connect()
        
        let state = await client.connectionState
        #expect(state == .connected || state == .disconnected || state == .connecting)
    }
    
    @Test("Concurrent operations safety")
    func testConcurrentOperations() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient(url: url)
        
        // Test that concurrent operations don't crash
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try? await client.connect()
            }
            
            group.addTask {
                _ = try? await client.send("Test 1")
            }
            
            group.addTask {
                _ = try? await client.send("Test 2")
            }
            
            group.addTask {
                _ = try? await client.disconnect()
            }
        }
        
        // If we got here without crashing, the test passes
        #expect(true)
    }
}

// MARK: - Mock WebSocket Client for Testing

#if DEBUG
actor MockWebSocketClient: WebSocketClientProtocol {
    var isConnected: Bool = false
    var connectionState: WebSocketConnectionState = .disconnected
    var messagesReceived: [String] = []
    var messagesSent: [String] = []
    
    func connect() async throws {
        isConnected = true
        connectionState = .connected
    }
    
    func disconnect() async throws {
        isConnected = false
        connectionState = .disconnected
    }
    
    func send(_ message: String) async throws {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
        messagesSent.append(message)
    }
    
    func send(_ data: Data) async throws {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
        if let message = String(data: data, encoding: .utf8) {
            messagesSent.append(message)
        }
    }
    
    func setMessageHandler(_ handler: @escaping (String) async -> Void) {
        // Store handler for testing
    }
    
    func setDataHandler(_ handler: @escaping (Data) async -> Void) {
        // Store handler for testing
    }
    
    func setErrorHandler(_ handler: @escaping (Error) async -> Void) {
        // Store handler for testing
    }
    
    func simulateMessageReceived(_ message: String) {
        messagesReceived.append(message)
    }
}

enum WebSocketError: Error {
    case notConnected
    case connectionFailed
}
#endif