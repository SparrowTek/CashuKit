//
//  Logger.swift
//  CashuKit
//
//  Structured logging system for CashuKit
//

import Foundation
import os.log

// MARK: - Log Level

public enum LogLevel: Int, Comparable, CaseIterable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Log Category

public enum LogCategory: String, CaseIterable, Sendable {
    case wallet = "wallet"
    case network = "network"
    case crypto = "crypto"
    case token = "token"
    case mint = "mint"
    case proof = "proof"
    case keychain = "keychain"
    case error = "error"
    case performance = "performance"
    
    var subsystem: String {
        return "com.sparrowtek.cashukit.\(rawValue)"
    }
}

// MARK: - Logger Protocol

public protocol LoggerProtocol: Sendable {
    func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int)
    func setMinimumLogLevel(_ level: LogLevel)
}

// MARK: - Logger Configuration

public struct LoggerConfiguration: Sendable {
    public let minimumLevel: LogLevel
    public let enableOSLog: Bool
    public let enableConsoleLog: Bool
    public let redactSensitiveData: Bool
    
    public init(
        minimumLevel: LogLevel = .info,
        enableOSLog: Bool = true,
        enableConsoleLog: Bool = false,
        redactSensitiveData: Bool = true
    ) {
        self.minimumLevel = minimumLevel
        self.enableOSLog = enableOSLog
        self.enableConsoleLog = enableConsoleLog
        self.redactSensitiveData = redactSensitiveData
    }
    
    public static let `default` = LoggerConfiguration()
    public static let debug = LoggerConfiguration(minimumLevel: .debug, enableConsoleLog: true)
    public static let production = LoggerConfiguration(minimumLevel: .warning, enableConsoleLog: false)
}

// MARK: - Logger Implementation

public final class Logger: LoggerProtocol, @unchecked Sendable {
    private var configuration: LoggerConfiguration
    private let loggers: [LogCategory: os.Logger]
    private let queue = DispatchQueue(label: "com.cashukit.logger", attributes: .concurrent)
    
    public static let shared = Logger()
    
    private init(configuration: LoggerConfiguration = .default) {
        self.configuration = configuration
        
        // Create OS loggers for each category
        var loggers: [LogCategory: os.Logger] = [:]
        for category in LogCategory.allCases {
            loggers[category] = os.Logger(subsystem: category.subsystem, category: category.rawValue)
        }
        self.loggers = loggers
    }
    
    public func configure(_ configuration: LoggerConfiguration) {
        queue.async(flags: .barrier) {
            self.configuration = configuration
        }
    }
    
    public func setMinimumLogLevel(_ level: LogLevel) {
        queue.async(flags: .barrier) {
            self.configuration = LoggerConfiguration(
                minimumLevel: level,
                enableOSLog: self.configuration.enableOSLog,
                enableConsoleLog: self.configuration.enableConsoleLog,
                redactSensitiveData: self.configuration.redactSensitiveData
            )
        }
    }
    
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .wallet,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        queue.async {
            guard level >= self.configuration.minimumLevel else { return }
            
            let filename = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = self.formatMessage(message, level: level, category: category, file: filename, function: function, line: line)
            
            // OS Log
            if self.configuration.enableOSLog, let logger = self.loggers[category] {
                logger.log(level: level.osLogType, "\(logMessage)")
            }
            
            // Console Log
            if self.configuration.enableConsoleLog {
                print(logMessage)
            }
        }
    }
    
    private func formatMessage(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let redactedMessage = configuration.redactSensitiveData ? redactSensitiveData(in: message) : message
        return "\(timestamp) \(level.emoji) [\(category.rawValue)] \(file):\(line) - \(function) - \(redactedMessage)"
    }
    
    private func redactSensitiveData(in message: String) -> String {
        var redacted = message
        
        // Redact hex strings that might be keys or secrets
        let hexPattern = #"\b[0-9a-fA-F]{32,}\b"#
        redacted = redacted.replacingOccurrences(
            of: hexPattern,
            with: "[REDACTED_HEX]",
            options: .regularExpression
        )
        
        // Redact potential private keys
        let privateKeyPatterns = [
            #"private[_\s]?key[:\s]*[^\s]+"#,
            #"secret[:\s]*[^\s]+"#,
            #"seed[:\s]*[^\s]+"#,
            #"mnemonic[:\s]*[^\s]+"#
        ]
        
        for pattern in privateKeyPatterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Redact lightning invoices
        let lnPattern = #"ln[a-z0-9]{10,}"#
        redacted = redacted.replacingOccurrences(
            of: lnPattern,
            with: "[REDACTED_INVOICE]",
            options: .regularExpression
        )
        
        // Redact token strings
        let tokenPattern = #"cashu[A-Za-z0-9+/=]{20,}"#
        redacted = redacted.replacingOccurrences(
            of: tokenPattern,
            with: "[REDACTED_TOKEN]",
            options: .regularExpression
        )
        
        return redacted
    }
}

// MARK: - Convenience Extensions

public extension Logger {
    func debug(_ message: String, category: LogCategory = .wallet, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .wallet, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .wallet, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // Performance logging helpers
    func logPerformance<T>(
        operation: String,
        category: LogCategory = .performance,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: @Sendable () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            info("\(operation) completed in \(String(format: "%.3f", duration))s", category: category, file: file, function: function, line: line)
        }
        return try await block()
    }
}

// MARK: - Global Logger Instance

public let logger = Logger.shared
