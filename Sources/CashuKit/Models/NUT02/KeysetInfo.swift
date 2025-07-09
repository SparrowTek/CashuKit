//
//  KeysetInfo.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 7/8/25.
//

/// Response structure for GET /v1/keysets
public struct GetKeysetsResponse: CashuCodabale {
    public let keysets: [KeysetInfo]
    
    public init(keysets: [KeysetInfo]) {
        self.keysets = keysets
    }
}

/// Keyset information structure
public struct KeysetInfo: CashuCodabale {
    public let id: String
    public let unit: String
    public let active: Bool
    public let inputFeePpk: Int?
    
    public init(id: String, unit: String, active: Bool, inputFeePpk: Int? = nil) {
        self.id = id
        self.unit = unit
        self.active = active
        self.inputFeePpk = inputFeePpk
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case unit
        case active
        case inputFeePpk = "input_fee_ppk"
    }
}
