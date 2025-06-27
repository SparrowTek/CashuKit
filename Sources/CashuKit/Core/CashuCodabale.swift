//
//  CashuCodabale.swift
//  CashuKit
//
//  Created by Thomas Rademaker on 6/27/25.
//

import Foundation

protocol CashuCodabale: CashuEncodable, CashuDecodable, Sendable {}
protocol CashuEncodable: Encodable, Sendable {}
protocol CashuDecodable: Decodable, Sendable {}
