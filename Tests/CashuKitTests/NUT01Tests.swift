//
//  NUT01Tests.swift
//  CashuKit
//
//  Tests for NUT-01: Mint public key exchange
//

import Testing
@testable import CashuKit

@Suite("NUT01 tests")
struct NUT01Tests {
    
    @Test
    func currencyUnitMinorUnits() {
        #expect(CurrencyUnit.btc.minorUnit == 8)
        #expect(CurrencyUnit.sat.minorUnit == 0)
        #expect(CurrencyUnit.msat.minorUnit == 0)
        #expect(CurrencyUnit.auth.minorUnit == 0)
        
        #expect(CurrencyUnit.usd.minorUnit == 2)
        #expect(CurrencyUnit.eur.minorUnit == 2)
        #expect(CurrencyUnit.gbp.minorUnit == 2)
        #expect(CurrencyUnit.jpy.minorUnit == 0)
        #expect(CurrencyUnit.bhd.minorUnit == 3)
        
        #expect(CurrencyUnit.usdt.minorUnit == 2)
        #expect(CurrencyUnit.usdc.minorUnit == 2)
        #expect(CurrencyUnit.eurc.minorUnit == 2)
        #expect(CurrencyUnit.gyen.minorUnit == 0)
    }
    
    @Test
    func currencyUnitDescriptions() {
        #expect(CurrencyUnit.btc.description == "Bitcoin")
        #expect(CurrencyUnit.sat.description == "Satoshi")
        #expect(CurrencyUnit.msat.description == "Millisatoshi")
        #expect(CurrencyUnit.auth.description == "Authentication Token")
        #expect(CurrencyUnit.usd.description == "US Dollar")
        #expect(CurrencyUnit.eur.description == "Euro")
        #expect(CurrencyUnit.usdt.description == "Tether USD")
        #expect(CurrencyUnit.usdc.description == "USD Coin")
    }
    
    @Test
    func urrencyUnitCategories() {
        // Bitcoin units
        #expect(CurrencyUnit.btc.isBitcoin)
        #expect(CurrencyUnit.sat.isBitcoin)
        #expect(CurrencyUnit.msat.isBitcoin)
        #expect(!CurrencyUnit.auth.isBitcoin)
        #expect(!CurrencyUnit.usd.isBitcoin)
        
        // ISO 4217 currencies
        #expect(CurrencyUnit.usd.isISO4217)
        #expect(CurrencyUnit.eur.isISO4217)
        #expect(CurrencyUnit.gbp.isISO4217)
        #expect(CurrencyUnit.jpy.isISO4217)
        #expect(CurrencyUnit.bhd.isISO4217)
        #expect(!CurrencyUnit.btc.isISO4217)
        #expect(!CurrencyUnit.usdt.isISO4217)
        
        // Stablecoins
        #expect(CurrencyUnit.usdt.isStablecoin)
        #expect(CurrencyUnit.usdc.isStablecoin)
        #expect(CurrencyUnit.eurc.isStablecoin)
        #expect(CurrencyUnit.gyen.isStablecoin)
        #expect(!CurrencyUnit.btc.isStablecoin)
        #expect(!CurrencyUnit.usd.isStablecoin)
    }
    
    @Test
    func currencyUnitRawValues() {
        #expect(CurrencyUnit.btc.rawValue == "btc")
        #expect(CurrencyUnit.sat.rawValue == "sat")
        #expect(CurrencyUnit.msat.rawValue == "msat")
        #expect(CurrencyUnit.usd.rawValue == "usd")
        #expect(CurrencyUnit.eur.rawValue == "eur")
        #expect(CurrencyUnit.usdt.rawValue == "usdt")
        #expect(CurrencyUnit.usdc.rawValue == "usdc")
    }
    
    @Test
    func currencyUnitFromRawValue() {
        #expect(CurrencyUnit(rawValue: "btc") == .btc)
        #expect(CurrencyUnit(rawValue: "sat") == .sat)
        #expect(CurrencyUnit(rawValue: "usd") == .usd)
        #expect(CurrencyUnit(rawValue: "eur") == .eur)
        #expect(CurrencyUnit(rawValue: "invalid") == nil)
        #expect(CurrencyUnit(rawValue: "") == nil)
    }
    
    // MARK: - Keyset Tests
    
    @Test
    func keysetValidation() async {
        let service = await KeyExchangeService()
        
        // Valid keyset
        let validKeyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "2": "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "4": "02fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
            ]
        )
        #expect(service.validateKeyset(validKeyset))
        
        // Invalid keyset - empty ID
        let invalidKeyset1 = Keyset(id: "", unit: "sat", keys: ["1": "02abcd..."])
        #expect(!service.validateKeyset(invalidKeyset1))
        
        // Invalid keyset - empty unit
        let invalidKeyset2 = Keyset(id: "0088553333AABBCC", unit: "", keys: ["1": "02abcd..."])
        #expect(!service.validateKeyset(invalidKeyset2))
        
        // Invalid keyset - no keys
        let invalidKeyset3 = Keyset(id: "0088553333AABBCC", unit: "sat", keys: [:])
        #expect(!service.validateKeyset(invalidKeyset3))
        
        // Invalid keyset - invalid public key format
        let invalidKeyset4 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["1": "invalid_key"]
        )
        #expect(!service.validateKeyset(invalidKeyset4))
        
        // Invalid keyset - wrong public key length
        let invalidKeyset5 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["1": "02abcdef"] // Too short
        )
        #expect(!service.validateKeyset(invalidKeyset5))
        
        // Invalid keyset - invalid public key prefix
        let invalidKeyset6 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["1": "01abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab"] // Invalid prefix
        )
        #expect(!service.validateKeyset(invalidKeyset6))
        
        // Invalid keyset - invalid amount
        let invalidKeyset7 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["0": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a"] // Amount 0
        )
        #expect(!service.validateKeyset(invalidKeyset7))
        
        // Invalid keyset - non-numeric amount
        let invalidKeyset8 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["abc": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a"]
        )
        #expect(!service.validateKeyset(invalidKeyset8))
    }
    
    @Test
    func keysetGetPublicKey() {
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "2": "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "4": "02fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
            ]
        )
        
        #expect(keyset.getPublicKey(for: 1) == "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a")
        #expect(keyset.getPublicKey(for: 2) == "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a")
        #expect(keyset.getPublicKey(for: 4) == "02fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321")
        #expect(keyset.getPublicKey(for: 8) == nil)
        #expect(keyset.getPublicKey(for: 0) == nil)
    }
    
    @Test
    func keysetGetSupportedAmounts() {
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcd...",
                "4": "03abcd...",
                "16": "02abcd...",
                "64": "03abcd..."
            ]
        )
        
        let supportedAmounts = keyset.getSupportedAmounts()
        #expect(supportedAmounts.sorted() == [1, 4, 16, 64])
    }
    
    @Test
    func keysetValidateKeys() {
        // Valid keys
        let validKeyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "2": "03fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
            ]
        )
        #expect(validKeyset.validateKeys())
        
        // Invalid keys - wrong length
        let invalidKeyset1 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["1": "02abcd"] // Too short
        )
        #expect(!invalidKeyset1.validateKeys())
        
        // Invalid keys - invalid hex
        let invalidKeyset2 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["1": "02abcdefghij567890abcdef1234567890abcdef1234567890abcdef1234567890ab"] // Invalid hex
        )
        #expect(!invalidKeyset2.validateKeys())
        
        // Invalid keys - wrong prefix
        let invalidKeyset3 = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: ["1": "01abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab"] // Invalid prefix
        )
        #expect(!invalidKeyset3.validateKeys())
    }
    
    // MARK: - Currency Unit Validation Tests
    
    @Test
    func currencyUnitValidation() async {
        let service = await KeyExchangeService()
        
        // Valid known currency units
        #expect(service.validateCurrencyUnit("btc"))
        #expect(service.validateCurrencyUnit("sat"))
        #expect(service.validateCurrencyUnit("usd"))
        #expect(service.validateCurrencyUnit("eur"))
        #expect(service.validateCurrencyUnit("usdt"))
        
        // Valid custom units (lowercase, alphanumeric)
        #expect(service.validateCurrencyUnit("custom"))
        #expect(service.validateCurrencyUnit("mytoken"))
        #expect(service.validateCurrencyUnit("test123"))
        
        // Invalid units
        #expect(!service.validateCurrencyUnit("")) // Empty
        #expect(!service.validateCurrencyUnit("USD")) // Uppercase
        #expect(!service.validateCurrencyUnit("test-token")) // Contains dash
        #expect(!service.validateCurrencyUnit("test_token")) // Contains underscore
        #expect(!service.validateCurrencyUnit("test token")) // Contains space
        #expect(!service.validateCurrencyUnit("test@token")) // Contains special character
    }
    
    @Test
    func amountValidationForUnit() async {
        let service = await KeyExchangeService()
        
        // Valid amounts for known units
        #expect(service.validateAmountForUnit(1, unit: "sat"))
        #expect(service.validateAmountForUnit(100, unit: "usd"))
        #expect(service.validateAmountForUnit(1000, unit: "btc"))
        
        // Invalid amounts
        #expect(!service.validateAmountForUnit(0, unit: "sat"))
        #expect(!service.validateAmountForUnit(-100, unit: "usd"))
        
        // Valid amounts for unknown units
        #expect(service.validateAmountForUnit(1, unit: "custom"))
        #expect(service.validateAmountForUnit(1000, unit: "unknown"))
        
        // Invalid amounts for unknown units
        #expect(!service.validateAmountForUnit(0, unit: "custom"))
        #expect(!service.validateAmountForUnit(-50, unit: "unknown"))
    }
    
    // MARK: - Unit Conversion Tests
    
    @Test
    func convertToMinorUnits() async {
        let service = await KeyExchangeService()
        
        // Bitcoin
        #expect(service.convertToMinorUnits(1.0, unit: .btc) == 100_000_000)
        #expect(service.convertToMinorUnits(0.00000001, unit: .btc) == 1)
        
        // Satoshi (already minor unit)
        #expect(service.convertToMinorUnits(1.0, unit: .sat) == 1)
        #expect(service.convertToMinorUnits(100.0, unit: .sat) == 100)
        
        // USD
        #expect(service.convertToMinorUnits(1.0, unit: .usd) == 100)
        #expect(service.convertToMinorUnits(1.23, unit: .usd) == 123)
        #expect(service.convertToMinorUnits(0.01, unit: .usd) == 1)
        
        // JPY (no minor unit)
        #expect(service.convertToMinorUnits(1.0, unit: .jpy) == 1)
        #expect(service.convertToMinorUnits(100.0, unit: .jpy) == 100)
        
        // BHD (3 decimal places)
        #expect(service.convertToMinorUnits(1.0, unit: .bhd) == 1000)
        #expect(service.convertToMinorUnits(1.234, unit: .bhd) == 1234)
        #expect(service.convertToMinorUnits(0.001, unit: .bhd) == 1)
    }
    
    @Test
    func testConvertFromMinorUnits() async {
        let service = await KeyExchangeService()
        
        // Bitcoin
        
        #expect(service.convertFromMinorUnits(100_000_000, unit: .btc) == 1.0)
        #expect(service.convertFromMinorUnits(1, unit: .btc) == 0.00000001)

        // Satoshi
        #expect(service.convertFromMinorUnits(1, unit: .sat) == 1.0)
        #expect(service.convertFromMinorUnits(100, unit: .sat) == 100.0)
        
        // USD
        #expect(service.convertFromMinorUnits(100, unit: .usd) == 1.0)
        #expect(service.convertFromMinorUnits(123, unit: .usd) == 1.23)
        #expect(service.convertFromMinorUnits(1, unit: .usd) == 0.01)
        
        // JPY
        #expect(service.convertFromMinorUnits(1, unit: .jpy) == 1.0)
        #expect(service.convertFromMinorUnits(100, unit: .jpy) == 100.0)
        
        // BHD
        #expect(service.convertFromMinorUnits(1000, unit: .bhd) == 1.0)
        #expect(service.convertFromMinorUnits(1234, unit: .bhd) == 1.234)
        #expect(service.convertFromMinorUnits(1, unit: .bhd) == 0.001)
    }
    
    // MARK: - GetKeysResponse Tests
    
    @Test
    func getKeysResponseValidation() {
        // Valid response
        let validKeyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "2": "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a"
            ]
        )
        let validResponse = GetKeysResponse(keysets: [validKeyset])
        #expect(validResponse.keysets.count == 1)
        
        // Empty response
        let emptyResponse = GetKeysResponse(keysets: [])
        #expect(emptyResponse.keysets.count == 0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func invalidKeysetIDValidation() async {
        let service = await KeyExchangeService()
        
        // Test with various invalid keyset IDs
        let invalidKeysets = [
            Keyset(id: "123", unit: "sat", keys: ["1": "02abcd..."]), // Too short
            Keyset(id: "gggggggggggggggg", unit: "sat", keys: ["1": "02abcd..."]), // Invalid hex
            Keyset(id: "123456789012345678", unit: "sat", keys: ["1": "02abcd..."]), // Too long
        ]
        
        for keyset in invalidKeysets {
            #expect(!service.validateKeyset(keyset))
        }
    }
    
    @Test
    func publicKeyValidation() {
        let validKeyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a", // Valid compressed key
                "2": "03fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"  // Valid compressed key
            ]
        )
        #expect(validKeyset.validateKeys())
        
        let invalidKeyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "04abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a", // Invalid prefix
                "2": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678"     // Wrong length
            ]
        )
        #expect(!invalidKeyset.validateKeys())
    }
    
    // MARK: - Integration Tests
    
    @Test
    func currencyUnitAllCasesCovered() {
        let allCases = CurrencyUnit.allCases
        
        // Ensure we have all expected currency units
        #expect(allCases.contains(.btc))
        #expect(allCases.contains(.sat))
        #expect(allCases.contains(.msat))
        #expect(allCases.contains(.auth))
        #expect(allCases.contains(.usd))
        #expect(allCases.contains(.eur))
        #expect(allCases.contains(.gbp))
        #expect(allCases.contains(.jpy))
        #expect(allCases.contains(.bhd))
        #expect(allCases.contains(.usdt))
        #expect(allCases.contains(.usdc))
        #expect(allCases.contains(.eurc))
        #expect(allCases.contains(.gyen))
        
        // Test that all units have valid descriptions and minor units
        for unit in allCases {
            #expect(!unit.description.isEmpty)
            #expect(unit.minorUnit >= 0)
            #expect(unit.minorUnit <= 8) // Reasonable upper bound
        }
    }
    
    @Test
    func keysetWithRealWorldAmounts() {
        // Test with typical Cashu denominations (powers of 2)
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "02abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "2": "03abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789a",
                "4": "02fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
                "8": "03fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
                "16": "02123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0",
                "32": "03123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0",
                "64": "02987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba0",
                "128": "03987654321fedcba0987654321fedcba0987654321fedcba0987654321fedcba0"
            ]
        )
        
        #expect(keyset.validateKeys())
        
        let supportedAmounts = keyset.getSupportedAmounts()
        let expectedAmounts = [1, 2, 4, 8, 16, 32, 64, 128]
        #expect(supportedAmounts.sorted() == expectedAmounts)
        
        // Test that we can get keys for all amounts
        for amount in expectedAmounts {
            #expect(keyset.getPublicKey(for: amount) != nil)
        }
        
        // Test that we can't get keys for unsupported amounts
        #expect(keyset.getPublicKey(for: 256) == nil)
        #expect(keyset.getPublicKey(for: 3) == nil)
        #expect(keyset.getPublicKey(for: 0) == nil)
    }
}
