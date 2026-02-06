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
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        
        // Configure maximum message size
        task.maximumMessageSize = configuration.maxFrameSize
        
        // Start the connection
        task.resume()
        
        do {
            // Validate the connection with a ping probe before marking it connected.
            try await sendPing(on: task)
            _isConnected = true
        } catch {
            task.cancel()
            webSocketTask = nil
            _isConnected = false
            throw WebSocketError.connectionFailed(error.localizedDescription)
        }
        
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
            try await withTimeout(seconds: configuration.connectionTimeout) {
                try await task.send(message)
            }
        } catch let webSocketError as WebSocketError {
            throw webSocketError
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
            try await withTimeout(seconds: configuration.connectionTimeout) {
                try await task.send(message)
            }
        } catch let webSocketError as WebSocketError {
            throw webSocketError
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
            let message = try await withTimeout(seconds: configuration.connectionTimeout) {
                try await task.receive()
            }
            
            switch message {
            case .string(let text):
                return .text(text)
            case .data(let data):
                return .data(data)
            @unknown default:
                throw WebSocketError.receiveFailed("Unknown message type")
            }
        } catch let webSocketError as WebSocketError {
            throw webSocketError
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
        
        try await sendPing(on: task)
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
        webSocketTask?.cancel()
        webSocketTask = nil
    }
    
    // MARK: - Private Methods
    
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
    
    private func sendPing(on task: URLSessionWebSocketTask) async throws {
        try await withTimeout(seconds: configuration.connectionTimeout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                task.sendPing { error in
                    if let error {
                        continuation.resume(throwing: WebSocketError.sendFailed("Ping failed: \(error.localizedDescription)"))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeoutNanoseconds = UInt64(max(seconds, 0.1) * 1_000_000_000)
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw WebSocketError.timeout
            }
            
            guard let firstResult = try await group.next() else {
                group.cancelAll()
                throw WebSocketError.timeout
            }
            
            group.cancelAll()
            return firstResult
        }
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
