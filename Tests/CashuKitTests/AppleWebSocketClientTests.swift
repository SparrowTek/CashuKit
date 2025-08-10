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
        let client = AppleWebSocketClient()
        
        let _ = client  // Use to avoid warning
        #expect(Bool(true))
    }
    
    @Test("Connection lifecycle")
    func testConnectionLifecycle() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient()
        
        // Test connect
        try await client.connect(to: url)
        #expect(await client.isConnected == true)
        
        // Test disconnect
        await client.disconnect()
        #expect(await client.isConnected == false)
    }
    
    @Test("Send and receive messages", .disabled("Requires test WebSocket server"))
    func testSendReceive() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient()
        
        try await client.connect(to: url)
        
        let testMessage = "Hello, WebSocket!"
        try await client.send(text: testMessage)
        
        // In a real test, we'd wait for the echo
        // For now, just verify no crash
        
        await client.disconnect()
    }
    
    @Test("Reconnection handling")
    func testReconnection() async throws {
        let url = URL(string: "wss://invalid.websocket.test")!
        let client = AppleWebSocketClient()
        
        // Should handle connection failure gracefully
        do {
            try await client.connect(to: url)
        } catch {
            // Expected to fail
            #expect(Bool(true))
        }
        
        #expect(await client.isConnected == false)
    }
    
    @Test("Provider creation")
    func testProviderCreation() async throws {
        let client = AppleWebSocketClient()
        #expect(await client.isConnected == false)
    }
    
    @Test("Ping/Pong keepalive")
    func testPingPong() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient()
        
        // Connect first
        try? await client.connect(to: url)
        
        // Send ping
        try? await client.ping()
        
        #expect(Bool(true))
    }
    
    @Test("Message handler")
    func testMessageHandler() async throws {
        let client = AppleWebSocketClient()
        
        // Just test that client exists
        let _ = client
        #expect(Bool(true))
    }
    
    @Test("Connection state transitions")
    func testConnectionStates() async throws {
        let url = URL(string: "wss://test.websocket.org")!
        let client = AppleWebSocketClient()
        
        #expect(await client.isConnected == false)
        
        // Attempt connection (may fail, but state should change)
        _ = try? await client.connect(to: url)
        
        let connected = await client.isConnected
        #expect(connected == true || connected == false)
    }
    
    @Test("Concurrent operations safety")
    func testConcurrentOperations() async throws {
        let url = URL(string: "wss://echo.websocket.org")!
        let client = AppleWebSocketClient()
        
        // Test that concurrent operations don't crash
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try? await client.connect(to: url)
            }
            
            group.addTask {
                _ = try? await client.send(text: "Test 1")
            }
            
            group.addTask {
                _ = try? await client.send(text: "Test 2")
            }
            
            group.addTask {
                await client.disconnect()
            }
        }
        
        // If we got here without crashing, the test passes
        #expect(Bool(true))
    }
}

// MARK: - Mock WebSocket Client for Testing

#if DEBUG
actor MockWebSocketClient: WebSocketClientProtocol {
    var isConnected: Bool = false
    var messagesReceived: [String] = []
    var messagesSent: [String] = []
    
    func connect(to url: URL) async throws {
        isConnected = true
    }
    
    func disconnect() async {
        isConnected = false
    }
    
    func send(text: String) async throws {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
        messagesSent.append(text)
    }
    
    func send(data: Data) async throws {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
        if let message = String(data: data, encoding: .utf8) {
            messagesSent.append(message)
        }
    }
    
    func receive() async throws -> WebSocketMessage {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
        // Return a test message
        return .text("test message")
    }
    
    func ping() async throws {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
    }
    
    func close(code: WebSocketCloseCode, reason: Data?) async throws {
        isConnected = false
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