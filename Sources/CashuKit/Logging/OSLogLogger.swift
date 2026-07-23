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
///
/// ## Thread Safety Analysis
/// This type is marked `@unchecked Sendable` because:
/// - `Logger` (os.log) is thread-safe by design
/// - `subsystem` and `category` are immutable after init
/// - `_minimumLevel` access is synchronized via `queue` with barrier writes and sync reads
/// - All mutable state access is protected by `queue`
public final class OSLogLogger: LoggerProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Thread-safe access to minimum log level
    public var minimumLevel: LogLevel {
        get { queue.sync { _minimumLevel } }
        set { queue.async(flags: .barrier) { self._minimumLevel = newValue } }
    }
    private var _minimumLevel: LogLevel
    
    private let subsystem: String
    private let category: String
    private let logger: Logger
    /// When true, redacted log lines are marked `privacy: .public` in the unified log.
    /// Defaults to false: even redacted wallet logs stay private so a regex gap can
    /// never leak funds-bearing material through a sysdiagnose.
    private let logPublicly: Bool
    
    // Serial queue for thread-safe operations (concurrent reads, barrier writes)
    private let queue = DispatchQueue(label: "com.cashukit.oslogger", attributes: .concurrent)
    
    // MARK: - Initialization
    
    /// Initialize with custom subsystem and category
    /// - Parameters:
    ///   - subsystem: The subsystem for logging (defaults to bundle identifier)
    ///   - category: The category for logging
    ///   - minimumLevel: The minimum log level to record
    /// - Parameter logPublicly: Marks log lines `privacy: .public`. Leave false in
    ///   production — redaction is regex-based defense-in-depth, not a guarantee.
    public init(
        subsystem: String? = nil,
        category: String = "CashuKit",
        minimumLevel: LogLevel = .info,
        logPublicly: Bool = false
    ) {
        self.subsystem = subsystem ?? Bundle.main.bundleIdentifier ?? "com.cashukit"
        self.category = category
        self._minimumLevel = minimumLevel
        self.logger = Logger(subsystem: self.subsystem, category: self.category)
        self.logPublicly = logPublicly
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

        let publicly = self.logPublicly
        queue.async {
            // Log with appropriate os.log level
            switch level {
            case .debug:
                if publicly { loggerCopy.debug("\(fullMessage, privacy: .public)") } else { loggerCopy.debug("\(fullMessage, privacy: .private)") }
            case .info:
                if publicly { loggerCopy.info("\(fullMessage, privacy: .public)") } else { loggerCopy.info("\(fullMessage, privacy: .private)") }
            case .warning:
                if publicly { loggerCopy.warning("\(fullMessage, privacy: .public)") } else { loggerCopy.warning("\(fullMessage, privacy: .private)") }
            case .error:
                if publicly { loggerCopy.error("\(fullMessage, privacy: .public)") } else { loggerCopy.error("\(fullMessage, privacy: .private)") }
            case .critical:
                if publicly { loggerCopy.critical("\(fullMessage, privacy: .public)") } else { loggerCopy.critical("\(fullMessage, privacy: .private)") }
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
            // Values run through the same redaction as messages: a token passed under a
            // harmless key ("payload") must not bypass the filters.
            return "\(key)=\(redactSensitiveData(in: String(describing: value)))"
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
            // Seed/mnemonic values are SPACE-SEPARATED word lists — consuming a single
            // token would redact only the first of 12–24 words.
            #"(?i)seed[:\s]*(?:[a-z]+\s+){0,23}[a-z0-9]+"#,
            #"(?i)mnemonic[:\s]*(?:[a-z]+\s+){0,23}[a-z]+"#,
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
        // Both base64 (+, /) and base64url (-, _) alphabets: V4 cashuB tokens are
        // base64url, and stopping at the first '-'/'_' leaks the token's tail.
        let cashuTokenPattern = #"cashu[A-Za-z0-9+/\-_=]{20,}"#
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
    
}