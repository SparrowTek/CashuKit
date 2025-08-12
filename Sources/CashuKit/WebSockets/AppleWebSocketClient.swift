//
//  AppleWebSocketClient.swift
//  CashuKit
//
//  Apple-specific WebSocket implementation using URLSessionWebSocketTask
//

import Foundation
import CoreCashu

/// Apple-specific WebSocket client using URLSessionWebSocketTask
public actor AppleWebSocketClient: WebSocketClientProtocol {
    
    // MARK: - Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let configuration: WebSocketConfiguration
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var _isConnected: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize with a URLSession and configuration
    /// - Parameters:
    ///   - session: The URLSession to use (defaults to shared)
    ///   - configuration: WebSocket configuration
    public init(
        session: URLSession = .shared,
        configuration: WebSocketConfiguration = WebSocketConfiguration()
    ) {
        self.session = session
        self.configuration = configuration
    }
    
    deinit {
        // Ensure all tasks are cancelled when deallocating
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel()
    }
    
    // MARK: - WebSocketClientProtocol Implementation
    
    public var isConnected: Bool {
        return _isConnected
    }
    
    public func connect(to url: URL) async throws {
        // Validate URL scheme
        guard url.scheme == "ws" || url.scheme == "wss" else {
            throw WebSocketError.invalidURL
        }
        
        // Close any existing connection
        await disconnect()
        
        // Create URLRequest with headers
        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.connectionTimeout
        
        // Add custom headers
        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create the WebSocket task
        webSocketTask = session.webSocketTask(with: request)
        
        // Configure maximum message size
        webSocketTask?.maximumMessageSize = configuration.maxFrameSize
        
        // Start the connection
        webSocketTask?.resume()
        
        // Wait for connection to be established
        // URLSessionWebSocketTask doesn't provide a direct connection callback,
        // so we mark as connected after resume
        _isConnected = true
        
        // Start listening for messages
        startReceiving()
        
        // Start ping timer if configured
        if configuration.pingInterval > 0 {
            startPingTimer()
        }
    }
    
    public func send(text: String) async throws {
        guard _isConnected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        
        do {
            try await task.send(message)
        } catch {
            // Check if connection was closed
            if !_isConnected {
                throw WebSocketError.connectionClosed
            }
            throw WebSocketError.sendFailed(error.localizedDescription)
        }
    }
    
    public func send(data: Data) async throws {
        guard _isConnected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        
        do {
            try await task.send(message)
        } catch {
            // Check if connection was closed
            if !_isConnected {
                throw WebSocketError.connectionClosed
            }
            throw WebSocketError.sendFailed(error.localizedDescription)
        }
    }
    
    public func receive() async throws -> WebSocketMessage {
        guard _isConnected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        do {
            let message = try await task.receive()
            
            switch message {
            case .string(let text):
                return .text(text)
            case .data(let data):
                return .data(data)
            @unknown default:
                throw WebSocketError.receiveFailed("Unknown message type")
            }
        } catch {
            // Check if connection was closed
            if !_isConnected {
                throw WebSocketError.connectionClosed
            }
            throw WebSocketError.receiveFailed(error.localizedDescription)
        }
    }
    
    public func ping() async throws {
        guard _isConnected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            task.sendPing { error in
                if let error = error {
                    continuation.resume(throwing: WebSocketError.sendFailed("Ping failed: \(error.localizedDescription)"))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    public func close(code: WebSocketCloseCode, reason: Data?) async throws {
        guard let task = webSocketTask else {
            return
        }
        
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code.rawValue) ?? .normalClosure
        
        task.cancel(with: closeCode, reason: reason)
        _isConnected = false
        stopPingTimer()
        webSocketTask = nil
    }
    
    public func disconnect() async {
        _isConnected = false
        stopPingTimer()
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel()
        webSocketTask = nil
    }
    
    // MARK: - Private Methods
    
    private func startReceiving() {
        guard let task = webSocketTask else { return }
        
        receiveTask?.cancel()
        receiveTask = Task {
            do {
                // This will keep the connection alive by continuously receiving
                while _isConnected && !Task.isCancelled {
                    _ = try await task.receive()
                }
            } catch {
                // Connection closed or error occurred
                if !Task.isCancelled {
                    await disconnect()
                }
            }
        }
    }
    
    private func startPingTimer() {
        stopPingTimer()
        
        let interval = configuration.pingInterval
        guard interval > 0 else { return }
        
        // Create a task that sends pings
        pingTask = Task {
            while _isConnected && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if _isConnected && !Task.isCancelled {
                    try? await ping()
                }
            }
        }
    }
    
    private func stopPingTimer() {
        pingTask?.cancel()
        pingTask = nil
    }
}

// MARK: - AppleWebSocketClientProvider

/// Provider for creating Apple WebSocket clients
public struct AppleWebSocketClientProvider: WebSocketClientProtocolProvider {
    
    private let session: URLSession
    
    /// Initialize with a URLSession
    /// - Parameter session: The URLSession to use for WebSocket connections
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func createClient() -> any WebSocketClientProtocol {
        AppleWebSocketClient(session: session)
    }
    
    public func createClient(configuration: WebSocketConfiguration) -> any WebSocketClientProtocol {
        AppleWebSocketClient(session: session, configuration: configuration)
    }
}

// MARK: - URLSession Extension

extension URLSession {
    
    /// Create a configured URLSession for WebSocket use
    /// - Parameters:
    ///   - configuration: URLSession configuration
    ///   - delegate: Optional delegate for handling events
    /// - Returns: Configured URLSession
    public static func webSocketSession(
        configuration: URLSessionConfiguration = .default,
        delegate: (any URLSessionDelegate)? = nil
    ) -> URLSession {
        // Configure for WebSockets
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        
        // Enable better performance for WebSockets
        configuration.shouldUseExtendedBackgroundIdleMode = true
        
        return URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }
}