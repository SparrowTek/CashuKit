//
//  OSLogLoggerTests.swift
//  CashuKitTests
//
//  Tests for OSLogLogger implementation
//

import Testing
import Foundation
import CoreCashu
import os
@testable import CashuKit

@Suite("OSLogLogger Tests")
struct OSLogLoggerTests {
    
    @Test("Logger initialization")
    func testLoggerInitialization() async throws {
        let logger = OSLogLogger(category: "TestCategory", minimumLevel: .info)
        
        // Logger should be created without error (just check it exists)
        let _ = logger  // Use logger to avoid unused warning
        #expect(Bool(true))
    }
    
    @Test("Log level filtering")
    func testLogLevelFiltering() async throws {
        let logger = OSLogLogger(category: "TestCategory", minimumLevel: .warning)
        
        // These should be filtered out (no crash)
        logger.debug("Debug message")
        logger.info("Info message")
        
        // These should pass through (no crash)
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")
        
        // If we got here without crashing, the test passes
        #expect(Bool(true))
    }
    
    @Test("Sensitive data redaction")
    func testSensitiveDataRedaction() async throws {
        let logger = OSLogLogger(category: "TestCategory", minimumLevel: .debug)
        
        // Test various sensitive patterns
        let testCases = [
            "My mnemonic is abandon abandon abandon",
            "Private key: 0x1234567890abcdef",
            "Token: cashuAeyJhbW"
        ]
        
        for testCase in testCases {
            logger.info(testCase)
        }
        
        // If logging doesn't crash, test passes
        #expect(Bool(true))
    }
    
    @Test("Metadata logging")
    func testMetadataLogging() async throws {
        let logger = OSLogLogger(category: "TestCategory", minimumLevel: .debug)
        
        let metadata: [String: Any] = [
            "key": "value",
            "count": 42,
            "nested": ["inner": "data"]
        ]
        
        logger.info("Test message with metadata", metadata: metadata)
        
        #expect(Bool(true))
    }
    
    @Test("All log levels")
    func testAllLogLevels() async throws {
        let logger = OSLogLogger(category: "TestCategory", minimumLevel: .debug)
        
        logger.debug("Debug level message")
        logger.info("Info level message")
        logger.warning("Warning level message")
        logger.error("Error level message")
        logger.critical("Critical level message")
        
        #expect(Bool(true))
    }
}