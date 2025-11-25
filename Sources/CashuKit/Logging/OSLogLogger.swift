//
//  OSLogLogger.swift
//  CashuKit
//
//  Apple-specific logger implementation using os.log
//

import Foundation
import CoreCashu
import os.log

/// Apple-specific logger that uses os.log for structured logging
public final class OSLogLogger: LoggerProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    public var minimumLevel: LogLevel
    private let subsystem: String
    private let category: String
    private let logger: Logger
    
    // Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.cashukit.oslogger", attributes: .concurrent)
    
    // MARK: - Initialization
    
    /// Initialize with custom subsystem and category
    /// - Parameters:
    ///   - subsystem: The subsystem for logging (defaults to bundle identifier)
    ///   - category: The category for logging
    ///   - minimumLevel: The minimum log level to record
    public init(
        subsystem: String? = nil,
        category: String = "CashuKit",
        minimumLevel: LogLevel = .info
    ) {
        self.subsystem = subsystem ?? Bundle.main.bundleIdentifier ?? "com.cashukit"
        self.category = category
        self.minimumLevel = minimumLevel
        self.logger = Logger(subsystem: self.subsystem, category: self.category)
    }
    
    // MARK: - LoggerProtocol Implementation
    
    public func debug(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: UInt
    ) {
        log(level: .debug, message: message(), metadata: metadata, file: file, function: function, line: line)
    }
    
    public func info(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: UInt
    ) {
        log(level: .info, message: message(), metadata: metadata, file: file, function: function, line: line)
    }
    
    public func warning(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: UInt
    ) {
        log(level: .warning, message: message(), metadata: metadata, file: file, function: function, line: line)
    }
    
    public func error(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: UInt
    ) {
        log(level: .error, message: message(), metadata: metadata, file: file, function: function, line: line)
    }
    
    public func critical(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: UInt
    ) {
        log(level: .critical, message: message(), metadata: metadata, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(
        level: LogLevel,
        message: String,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: UInt
    ) {
        // Pre-process values on current thread to avoid Sendable issues
        guard level >= self.minimumLevel else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let location = "\(fileName):\(line)"

        // Format metadata on current thread
        let metadataString = self.formatMetadata(metadata)

        // Redact sensitive information on current thread
        let redactedMessage = self.redactSensitiveData(in: message)

        // Create full log message
        let fullMessage = "\(location) - \(function)\(metadataString) - \(redactedMessage)"

        // Capture local copies for the queue
        let loggerCopy = self.logger

        queue.async {
            // Log with appropriate os.log level
            switch level {
            case .debug:
                loggerCopy.debug("\(fullMessage, privacy: .public)")
            case .info:
                loggerCopy.info("\(fullMessage, privacy: .public)")
            case .warning:
                loggerCopy.warning("\(fullMessage, privacy: .public)")
            case .error:
                loggerCopy.error("\(fullMessage, privacy: .public)")
            case .critical:
                loggerCopy.critical("\(fullMessage, privacy: .public)")
            }
        }
    }
    
    private func formatMetadata(_ metadata: [String: Any]?) -> String {
        guard let metadata = metadata, !metadata.isEmpty else { return "" }
        
        let formattedPairs = metadata.map { key, value in
            // Apply privacy markers for sensitive keys
            if isSensitiveKey(key) {
                return "\(key)=[REDACTED]"
            }
            return "\(key)=\(value)"
        }.joined(separator: ", ")
        
        return " [\(formattedPairs)]"
    }
    
    private func isSensitiveKey(_ key: String) -> Bool {
        let sensitiveKeys = [
            "password", "token", "secret", "key", "seed",
            "mnemonic", "private", "authorization", "bearer"
        ]
        
        let lowercasedKey = key.lowercased()
        return sensitiveKeys.contains { lowercasedKey.contains($0) }
    }
    
    private func redactSensitiveData(in message: String) -> String {
        var redacted = message
        
        // Redact hex strings that might be keys or secrets (32+ characters)
        let hexPattern = #"\b[0-9a-fA-F]{32,}\b"#
        redacted = redacted.replacingOccurrences(
            of: hexPattern,
            with: "[REDACTED_HEX]",
            options: .regularExpression
        )
        
        // Redact potential private keys and sensitive data
        let sensitivePatterns = [
            #"(?i)private[_\s]?key[:\s]*[^\s]+"#,
            #"(?i)secret[:\s]*[^\s]+"#,
            #"(?i)seed[:\s]*[^\s]+"#,
            #"(?i)mnemonic[:\s]*[^\s]+"#,
            #"(?i)password[:\s]*[^\s]+"#
        ]
        
        for pattern in sensitivePatterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: .regularExpression
            )
        }
        
        // Redact Cashu tokens (start with "cashu" followed by base64-like characters)
        let cashuTokenPattern = #"cashu[A-Za-z0-9+/=]{20,}"#
        redacted = redacted.replacingOccurrences(
            of: cashuTokenPattern,
            with: "[REDACTED_CASHU_TOKEN]",
            options: .regularExpression
        )
        
        // Redact Lightning invoices
        let lightningPattern = #"ln[a-z0-9]{10,}"#
        redacted = redacted.replacingOccurrences(
            of: lightningPattern,
            with: "[REDACTED_INVOICE]",
            options: .regularExpression
        )
        
        // Redact Authorization headers
        let authPattern = #"(?i)authorization[:\s]+bearer\s+[A-Za-z0-9\-_.+/=]+"#
        redacted = redacted.replacingOccurrences(
            of: authPattern,
            with: "[REDACTED_AUTH]",
            options: .regularExpression
        )
        
        return redacted
    }
}

// MARK: - OSLogLogger Configuration

public extension OSLogLogger {
    
    /// Predefined logger for wallet operations
    static func wallet(minimumLevel: LogLevel = .info) -> OSLogLogger {
        OSLogLogger(category: "Wallet", minimumLevel: minimumLevel)
    }
    
    /// Predefined logger for network operations
    static func network(minimumLevel: LogLevel = .info) -> OSLogLogger {
        OSLogLogger(category: "Network", minimumLevel: minimumLevel)
    }
    
    /// Predefined logger for cryptographic operations
    static func crypto(minimumLevel: LogLevel = .warning) -> OSLogLogger {
        OSLogLogger(category: "Crypto", minimumLevel: minimumLevel)
    }
    
    /// Predefined logger for keychain operations
    static func keychain(minimumLevel: LogLevel = .warning) -> OSLogLogger {
        OSLogLogger(category: "Keychain", minimumLevel: minimumLevel)
    }
}

// MARK: - Convenience Methods

public extension OSLogLogger {
    
    /// Create a child logger with a specific category
    func child(category: String) -> OSLogLogger {
        OSLogLogger(
            subsystem: self.subsystem,
            category: "\(self.category).\(category)",
            minimumLevel: self.minimumLevel
        )
    }
    
    /// Update the minimum log level
    func setMinimumLevel(_ level: LogLevel) {
        queue.async(flags: .barrier) {
            self.minimumLevel = level
        }
    }
}