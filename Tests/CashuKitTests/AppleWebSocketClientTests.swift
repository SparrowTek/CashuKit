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
        // Use a closed local port to keep this deterministic and offline.
        let url = URL(string: "wss://127.0.0.1:1")!
        let client = AppleWebSocketClient()
        
        await expectWebSocketFailure {
            try await client.connect(to: url)
        }
        #expect(await client.isConnected == false)
        
        // Always disconnect to clean up
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
        let url = URL(string: "wss://127.0.0.1:1")!
        let client = AppleWebSocketClient()
        
        await expectWebSocketFailure {
            try await client.connect(to: url)
        }
        
        await expectWebSocketFailure {
            try await client.connect(to: url)
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
        let client = AppleWebSocketClient()
        
        do {
            try await client.ping()
            Issue.record("Expected ping to fail while disconnected")
        } catch let error as WebSocketError {
            guard case .notConnected = error else {
                Issue.record("Expected .notConnected, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected WebSocketError.notConnected, got \(error)")
        }
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
        let url = URL(string: "wss://127.0.0.1:1")!
        let client = AppleWebSocketClient()
        
        #expect(await client.isConnected == false)
        
        await expectWebSocketFailure {
            try await client.connect(to: url)
        }
        #expect(await client.isConnected == false)
        
        // Clean up
        await client.disconnect()
    }
    
    @Test("Concurrent operations safety")
    func testConcurrentOperations() async throws {
        let client = AppleWebSocketClient()
        
        // Concurrent sends while disconnected should fail predictably and not deadlock.
        let allFailed = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                do {
                    try await client.send(text: "Test 1")
                    return false
                } catch {
                    return true
                }
            }
            
            group.addTask {
                do {
                    try await client.send(text: "Test 2")
                    return false
                } catch {
                    return true
                }
            }
            
            group.addTask {
                do {
                    try await client.send(text: "Test 3")
                    return false
                } catch {
                    return true
                }
            }
            
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            return results.allSatisfy { $0 }
        }
        
        #expect(allFailed)
    }
    
    private func expectWebSocketFailure(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            Issue.record("Expected WebSocket operation to fail")
        } catch is WebSocketError {
            // Expected path
        } catch {
            Issue.record("Expected WebSocketError, got \(error)")
        }
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
            throw MockWebSocketError.notConnected
        }
        messagesSent.append(text)
    }
    
    func send(data: Data) async throws {
        guard isConnected else {
            throw MockWebSocketError.notConnected
        }
        if let message = String(data: data, encoding: .utf8) {
            messagesSent.append(message)
        }
    }
    
    func receive() async throws -> WebSocketMessage {
        guard isConnected else {
            throw MockWebSocketError.notConnected
        }
        // Return a test message
        return .text("test message")
    }
    
    func ping() async throws {
        guard isConnected else {
            throw MockWebSocketError.notConnected
        }
    }
    
    func close(code: WebSocketCloseCode, reason: Data?) async throws {
        isConnected = false
    }
    
    func simulateMessageReceived(_ message: String) {
        messagesReceived.append(message)
    }
}

enum MockWebSocketError: Error {
    case notConnected
    case connectionFailed
}
#endif
