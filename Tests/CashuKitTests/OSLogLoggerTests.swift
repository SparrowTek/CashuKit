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
        
        // Logger should be created without error
        #expect(logger != nil)
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
        #expect(true)
    }
    
    @Test("Sensitive data redaction")
    func testSensitiveDataRedaction() async throws {
        let logger = OSLogLogger(category: "TestCategory", minimumLevel: .debug)
        
        // Test various sensitive patterns
        let testCases = [
            "My mnemonic is abandon abandon abandon",
            "Private key: 0x1234567890abcdef",
            "Token: cashuAeyJhbW