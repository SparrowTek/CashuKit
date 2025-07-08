//
//  CashuCodabale.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

public protocol CashuCodabale: CashuEncodable, CashuDecodable, Sendable {}
public protocol CashuEncodable: Encodable, Sendable {}
public protocol CashuDecodable: Decodable, Sendable {}
