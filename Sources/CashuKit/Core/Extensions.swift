//
//  Extensions.swift
//  CashuKit
//
//  Shared extensions for CashuKit
//

import Foundation

// MARK: - Data Extensions

extension Data {
    /// Convert hex string to Data
    public init?(hexString: String) {
        let cleanHex = hexString.replacingOccurrences(of: " ", with: "")
        guard cleanHex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = cleanHex.startIndex
        
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = cleanHex[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            
            index = nextIndex
        }
        
        self = data
    }
    
    /// Convert Data to hex string
    public var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string is a valid hex string
    public var isValidHex: Bool {
        let hexRegex = "^[0-9a-fA-F]+$"
        return range(of: hexRegex, options: .regularExpression) != nil
    }
    
    /// Convert hex string to Data
    public var hexData: Data? {
        return Data(hexString: self)
    }
} 