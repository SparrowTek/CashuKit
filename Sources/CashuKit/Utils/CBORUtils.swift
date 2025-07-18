//
//  CBORUtils.swift
//  CashuKit
//
//  CBOR encoding and decoding utilities for Cashu tokens and payment requests
//

import Foundation
import SwiftCBOR

// MARK: - CBOR Encoding

/// Encode a Codable object to CBOR data
public func encodeToCBOR<T: Encodable>(_ value: T) throws -> Data {
    // Convert to dictionary first
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(value)
    let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
    
    // Convert to CBOR
    let cbor = try encodeDictionaryToCBOR(dict)
    return Data(cbor.encode())
}

/// Decode CBOR data to a Codable object
public func decodeFromCBOR<T: Decodable>(_ data: Data, type: T.Type = T.self) throws -> T {
    // Decode CBOR
    guard let cbor = try CBOR.decode(data.bytes) else {
        throw CashuError.invalidTokenFormat
    }
    
    // Convert to dictionary
    guard var dict = cborToSwiftValue(cbor) as? [String: Any] else {
        throw CashuError.invalidTokenFormat
    }
    
    // Fix boolean fields that CBOR encoded as integers
    dict = fixBooleanFields(in: dict) as? [String: Any] ?? dict
    
    // Convert to JSON and decode
    let jsonData = try JSONSerialization.data(withJSONObject: dict)
    let decoder = JSONDecoder()
    return try decoder.decode(T.self, from: jsonData)
}

/// Fix boolean fields that were encoded as integers by CBOR
private func fixBooleanFields(in value: Any) -> Any {
    switch value {
    case var dict as [String: Any]:
        // Known boolean fields in our protocol
        let booleanFields = ["s"] // single use flag
        
        for (key, val) in dict {
            if booleanFields.contains(key) {
                // Convert 0/1 integers to booleans
                if let intVal = val as? Int {
                    dict[key] = intVal != 0
                }
            } else {
                // Recursively fix nested structures
                dict[key] = fixBooleanFields(in: val)
            }
        }
        return dict
        
    case let array as [Any]:
        return array.map { fixBooleanFields(in: $0) }
        
    default:
        return value
    }
}

// MARK: - Private Helpers

/// Convert Swift dictionary to CBOR
private func encodeDictionaryToCBOR(_ dict: [String: Any]) throws -> CBOR {
    var cborMap: [CBOR: CBOR] = [:]
    
    for (key, value) in dict {
        let keyCBOR = CBOR.utf8String(key)
        let valueCBOR = try swiftValueToCBOR(value)
        cborMap[keyCBOR] = valueCBOR
    }
    
    return CBOR.map(cborMap)
}

/// Convert Swift value to CBOR
private func swiftValueToCBOR(_ value: Any) throws -> CBOR {
    switch value {
    case let string as String:
        return CBOR.utf8String(string)
    case let int as Int:
        if int >= 0 {
            return CBOR.unsignedInt(UInt64(int))
        } else {
            return CBOR.negativeInt(UInt64(-int - 1))
        }
    case let uint as UInt:
        return CBOR.unsignedInt(UInt64(uint))
    case let bool as Bool:
        return CBOR.boolean(bool)
    case let data as Data:
        return CBOR.byteString(data.bytes)
    case let array as [Any]:
        let cborArray = try array.map { try swiftValueToCBOR($0) }
        return CBOR.array(cborArray)
    case let dict as [String: Any]:
        return try encodeDictionaryToCBOR(dict)
    case is NSNull:
        return CBOR.null
    default:
        // Try to convert to string as fallback
        return CBOR.utf8String(String(describing: value))
    }
}

/// Convert CBOR to Swift value
private func cborToSwiftValue(_ cbor: CBOR) -> Any {
    switch cbor {
    case .utf8String(let string):
        return string
    case .byteString(let bytes):
        return Data(bytes)
    case .unsignedInt(let uint):
        // CBOR often encodes booleans as 0/1
        // This is a heuristic to handle boolean fields
        if uint == 0 || uint == 1 {
            // We'll keep it as Int for now, but the decoder will handle conversion
            return Int(uint)
        }
        return uint
    case .negativeInt(let int):
        return -Int(int) - 1
    case .boolean(let bool):
        return bool
    case .null:
        return NSNull()
    case .array(let array):
        return array.map { cborToSwiftValue($0) }
    case .map(let map):
        var dict: [String: Any] = [:]
        for (key, value) in map {
            if case .utf8String(let keyString) = key {
                dict[keyString] = cborToSwiftValue(value)
            }
        }
        return dict
    case .float(let float):
        return float
    case .double(let double):
        return double
    default:
        return NSNull()
    }
}

// MARK: - Data Extension

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}