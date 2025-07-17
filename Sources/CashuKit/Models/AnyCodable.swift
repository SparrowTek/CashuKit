//
//  AnyCodable.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 7/8/25.
//

import Foundation

/// Universal codable value wrapper for flexible JSON handling
/// Replaces both AnyCodableValue and SendableValue for consistent type handling
public enum AnyCodable: CashuCodabale {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    
    /// The underlying Any value
    public var anyValue: Any {
        switch self {
        case .int(let value): return value
        case .double(let value): return value
        case .string(let value): return value
        case .bool(let value): return value
        case .array(let values): return values.map { $0.anyValue }
        case .dictionary(let dict): return dict.mapValues { $0.anyValue }
        }
    }
    
    /// Get string value if this is a string case
    public var stringValue: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }
    
    /// Get dictionary value if this is a dictionary case
    public var dictionaryValue: [String: Any]? {
        if case .dictionary(let dict) = self {
            return dict.mapValues { $0.anyValue }
        }
        return nil
    }
    
    /// Get array value if this is an array case
    public var arrayValue: [Any]? {
        if case .array(let arr) = self {
            return arr.map { $0.anyValue }
        }
        return nil
    }
    
    /// Get int value if this is an int case
    public var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
    
    /// Get bool value if this is a bool case
    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
    
    /// Get double value if this is a double case
    public var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }
    
    public init<T: Codable>(_ value: T) {
        if let intValue = value as? Int {
            self = .int(intValue)
        } else if let doubleValue = value as? Double {
            self = .double(doubleValue)
        } else if let stringValue = value as? String {
            self = .string(stringValue)
        } else if let boolValue = value as? Bool {
            self = .bool(boolValue)
        } else {
            self = .string(String(describing: value))
        }
    }
    
    public init?(anyValue: Any) {
        switch anyValue {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            let codableArray = array.compactMap { AnyCodable(anyValue: $0) }
            if codableArray.count == array.count {
                self = .array(codableArray)
            } else {
                return nil
            }
        case let dict as [String: Any]:
            let codableDict = dict.compactMapValues { AnyCodable(anyValue: $0) }
            if codableDict.count == dict.count {
                self = .dictionary(codableDict)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .dictionary(let dict):
            try container.encode(dict)
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self = .array(arrayValue)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictValue)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
