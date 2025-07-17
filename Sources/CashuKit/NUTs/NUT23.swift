//
//  NUT23.swift
//  CashuKit
//
//  NUT-23: BOLT11 payment method
//

import Foundation
@preconcurrency import P256K

// MARK: - Mint Quote Models

/// Mint quote state as defined in NUT-23
public enum MintQuoteState: String, CaseIterable, CashuCodabale {
    case unpaid = "UNPAID"   // Quote's request has not been paid yet
    case paid = "PAID"       // Quote's request has been paid but ecash not issued yet
    case issued = "ISSUED"   // Quote has been paid and ecash has been issued
    
    /// Whether the quote is in a final state
    public var isFinal: Bool {
        return self == .issued
    }
    
    /// Whether payment is still possible
    public var canPay: Bool {
        return self == .unpaid
    }
}

/// Request for creating a BOLT11 mint quote
public struct PostMintQuoteBolt11Request: CashuCodabale, Sendable {
    /// Amount to mint
    public let amount: Int
    
    /// Unit (e.g., "sat")
    public let unit: String
    
    /// Optional description for the invoice
    public let description: String?
    
    public init(amount: Int, unit: String, description: String? = nil) {
        self.amount = amount
        self.unit = unit
        self.description = description
    }
}

/// Response for a BOLT11 mint quote
public struct PostMintQuoteBolt11Response: CashuCodabale, Sendable {
    /// Quote ID
    public let quote: String
    
    /// The bolt11 invoice to pay
    public let request: String
    
    /// Amount to mint
    public let amount: Int
    
    /// Unit (e.g., "sat")
    public let unit: String
    
    /// Quote state
    public let state: MintQuoteState
    
    /// Unix timestamp until which the request can be paid
    public let expiry: Int?
    
    public init(quote: String, request: String, amount: Int, unit: String, state: MintQuoteState, expiry: Int? = nil) {
        self.quote = quote
        self.request = request
        self.amount = amount
        self.unit = unit
        self.state = state
        self.expiry = expiry
    }
}

// MARK: - Melt Quote Models

/// Options for amountless invoices
public struct AmountlessOption: CashuCodabale, Sendable {
    /// Amount in millisatoshi
    public let amountMsat: Int
    
    private enum CodingKeys: String, CodingKey {
        case amountMsat = "amount_msat"
    }
    
    public init(amountMsat: Int) {
        self.amountMsat = amountMsat
    }
}

/// Options for BOLT11 melt quote
public struct Bolt11MeltOptions: CashuCodabale, Sendable {
    /// Support for amountless invoices
    public let amountless: AmountlessOption?
    
    public init(amountless: AmountlessOption? = nil) {
        self.amountless = amountless
    }
}

/// Extended request for creating a BOLT11 melt quote with NUT-23 specific options
public struct PostMeltQuoteBolt11RequestNUT23: CashuCodabale, Sendable {
    /// Lightning invoice to be paid
    public let request: String
    
    /// Unit the wallet would like to pay with
    public let unit: String
    
    /// Optional options for amountless invoices
    public let options: Bolt11MeltOptions?
    
    public init(request: String, unit: String, options: Bolt11MeltOptions? = nil) {
        self.request = request
        self.unit = unit
        self.options = options
    }
}

/// Response for a BOLT11 melt quote
public struct PostMeltQuoteBolt11Response: CashuCodabale, Sendable {
    /// Quote ID
    public let quote: String
    
    /// Lightning invoice that will be paid
    public let request: String
    
    /// Amount to be paid
    public let amount: Int
    
    /// Unit
    public let unit: String
    
    /// Additional fee reserve required for the Lightning payment
    public let feeReserve: Int
    
    /// Quote state
    public let state: MeltQuoteState
    
    /// Unix timestamp of quote expiry
    public let expiry: Int
    
    /// Payment preimage (hex string) - present after successful payment
    public let paymentPreimage: String?
    
    private enum CodingKeys: String, CodingKey {
        case quote
        case request
        case amount
        case unit
        case feeReserve = "fee_reserve"
        case state
        case expiry
        case paymentPreimage = "payment_preimage"
    }
    
    public init(quote: String, request: String, amount: Int, unit: String, feeReserve: Int, state: MeltQuoteState, expiry: Int, paymentPreimage: String? = nil) {
        self.quote = quote
        self.request = request
        self.amount = amount
        self.unit = unit
        self.feeReserve = feeReserve
        self.state = state
        self.expiry = expiry
        self.paymentPreimage = paymentPreimage
    }
}

// MARK: - Melt Request/Response with Change

/// Melt request with optional outputs for change
public struct PostMeltBolt11Request: CashuCodabale, Sendable {
    /// Quote ID
    public let quote: String
    
    /// Proofs to melt
    public let inputs: [Proof]
    
    /// Optional blinded messages for receiving change
    public let outputs: [BlindedMessage]?
    
    public init(quote: String, inputs: [Proof], outputs: [BlindedMessage]? = nil) {
        self.quote = quote
        self.inputs = inputs
        self.outputs = outputs
    }
}

/// Melt response with optional change
public struct PostMeltBolt11Response: CashuCodabale, Sendable {
    /// Quote ID
    public let quote: String
    
    /// Lightning invoice that was paid
    public let request: String
    
    /// Amount paid
    public let amount: Int
    
    /// Unit
    public let unit: String
    
    /// Fee reserve that was used
    public let feeReserve: Int
    
    /// Payment state
    public let state: MeltQuoteState
    
    /// Unix timestamp of quote expiry
    public let expiry: Int
    
    /// Payment preimage (hex string)
    public let paymentPreimage: String
    
    /// Blind signatures for change (if outputs were provided and there's change)
    public let change: [BlindSignature]?
    
    private enum CodingKeys: String, CodingKey {
        case quote
        case request
        case amount
        case unit
        case feeReserve = "fee_reserve"
        case state
        case expiry
        case paymentPreimage = "payment_preimage"
        case change
    }
    
    public init(quote: String, request: String, amount: Int, unit: String, feeReserve: Int, state: MeltQuoteState, expiry: Int, paymentPreimage: String, change: [BlindSignature]? = nil) {
        self.quote = quote
        self.request = request
        self.amount = amount
        self.unit = unit
        self.feeReserve = feeReserve
        self.state = state
        self.expiry = expiry
        self.paymentPreimage = paymentPreimage
        self.change = change
    }
}

// MARK: - Settings

/// BOLT11-specific mint method options
public struct Bolt11MintOptions: CashuCodabale, Sendable {
    /// Whether the backend supports providing an invoice description
    public let description: Bool
    
    public init(description: Bool) {
        self.description = description
    }
}

/// BOLT11-specific melt method options
public struct Bolt11MeltMethodOptions: CashuCodabale, Sendable {
    /// Whether amountless invoices are supported
    public let amountless: Bool
    
    public init(amountless: Bool) {
        self.amountless = amountless
    }
}

// MARK: - Extensions

// PaymentMethod.bolt11 is already defined in NUT05

// MARK: - Helper Types

/// Helper struct for calculating melt fees
public struct MeltFeeCalculation {
    public let amount: Int
    public let feeReserve: Int
    public let inputFees: Int
    
    public var total: Int {
        amount + feeReserve + inputFees
    }
    
    public init(amount: Int, feeReserve: Int, inputFeePPK: Int, numInputs: Int) {
        self.amount = amount
        self.feeReserve = feeReserve
        // Calculate input fees (round up)
        self.inputFees = (inputFeePPK * numInputs + 999) / 1000
    }
}