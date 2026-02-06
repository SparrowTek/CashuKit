//
//  CashuKit.swift
//  CashuKit
//

import Foundation
import CoreCashu

// Apple-specific entry point for CashuKit
// This file provides convenience methods for Apple platforms
public struct CashuKit {
    /// Version of CashuKit for Apple platforms
    public static let version = "1.0.0"
    
    /// Check if CashuKit is properly configured
    public static var isConfigured: Bool {
        return configurationIssues().isEmpty
    }

    /// Return a list of runtime configuration issues.
    public static func configurationIssues() -> [String] {
        var issues: [String] = []
        if Bundle.main.bundleIdentifier == nil {
            issues.append("Missing bundle identifier")
        }
        return issues
    }
}
