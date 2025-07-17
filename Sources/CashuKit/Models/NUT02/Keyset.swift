//
//  Keyset.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 7/8/25.
//

/// Response structure for GET /v1/keys and GET /v1/keys/{keyset_id}
public struct GetKeysResponse: CashuCodabale {
    public let keysets: [Keyset]
    
    public init(keysets: [Keyset]) {
        self.keysets = keysets
    }
}


/// Keyset with public keys
public struct Keyset: CashuCodabale {
    public let id: String
    public let unit: String
    public let keys: [String: String] // amount -> public key
    
    public init(id: String, unit: String, keys: [String: String]) {
        self.id = id
        self.unit = unit
        self.keys = keys
    }
    
    /// Get the public key for a specific amount
    public func getPublicKey(for amount: Int) -> String? {
        return keys[String(amount)]
    }
    
    /// Get all amounts supported by this keyset
    public func getSupportedAmounts() -> [Int] {
        return keys.keys.compactMap { Int($0) }.sorted()
    }
    
    /// Validate that all keys are valid compressed public keys
    public func validateKeys() -> Bool {
        return keys.values.allSatisfy { key in
            // Check valid hex and correct length for compressed keys
            guard key.isValidHex && key.count == 66 else { // 33 bytes compressed key = 66 hex chars
                return false
            }
            
            // Check that key starts with 02 or 03 (compressed format)
            let prefix = String(key.prefix(2))
            return prefix == "02" || prefix == "03"
        }
    }
}
