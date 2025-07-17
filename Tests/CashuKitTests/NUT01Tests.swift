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
    
    // MARK: - NUT-01 Test Vectors
    
    @Test("Invalid keyset test vectors - missing byte")
    func invalidKeysetMissingByte() {
        // Key 1 is missing a byte (should be 66 hex chars, but only has 64)
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38", // Missing byte
                "2": "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de",
                "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
                "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528"
            ]
        )
        
        // This keyset should be rejected because key "1" is invalid (missing byte)
        #expect(!keyset.validateKeys())
    }
    
    @Test("Invalid keyset test vectors - uncompressed format")
    func invalidKeysetUncompressedFormat() {
        // Key 2 is a valid key but is not in the compressed format (starts with 04)
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc",
                "2": "04fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de3625246cb2c27dac965cb7200a5986467eee92eb7d496bbf1453b074e223e481", // Uncompressed
                "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
                "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528"
            ]
        )
        
        // This keyset should be rejected because key "2" is uncompressed
        #expect(!keyset.validateKeys())
    }
    
    @Test("Valid keyset test vectors - standard")
    func validKeysetStandard() {
        // Valid keyset that should be accepted
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc",
                "2": "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de",
                "4": "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303",
                "8": "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528"
            ]
        )
        
        // This keyset should be accepted
        #expect(keyset.validateKeys())
        
        // Verify all keys are accessible
        #expect(keyset.getPublicKey(for: 1) == "03a40f20667ed53513075dc51e715ff2046cad64eb68960632269ba7f0210e38bc")
        #expect(keyset.getPublicKey(for: 2) == "03fd4ce5a16b65576145949e6f99f445f8249fee17c606b688b504a849cdc452de")
        #expect(keyset.getPublicKey(for: 4) == "02648eccfa4c026960966276fa5a4cae46ce0fd432211a4f449bf84f13aa5f8303")
        #expect(keyset.getPublicKey(for: 8) == "02fdfd6796bfeac490cbee12f778f867f0a2c68f6508d17c649759ea0dc3547528")
    }
    
    @Test("Valid keyset test vectors - large amounts")
    func validKeysetLargeAmounts() {
        // Valid keyset with large amounts (includes amount > Int64.max)
        let keyset = Keyset(
            id: "0088553333AABBCC",
            unit: "sat",
            keys: [
                "1": "03ba786a2c0745f8c30e490288acd7a72dd53d65afd292ddefa326a4a3fa14c566",
                "2": "03361cd8bd1329fea797a6add1cf1990ffcf2270ceb9fc81eeee0e8e9c1bd0cdf5",
                "4": "036e378bcf78738ddf68859293c69778035740e41138ab183c94f8fee7572214c7",
                "8": "03909d73beaf28edfb283dbeb8da321afd40651e8902fcf5454ecc7d69788626c0",
                "16": "028a36f0e6638ea7466665fe174d958212723019ec08f9ce6898d897f88e68aa5d",
                "32": "03a97a40e146adee2687ac60c2ba2586a90f970de92a9d0e6cae5a4b9965f54612",
                "64": "03ce86f0c197aab181ddba0cfc5c5576e11dfd5164d9f3d4a3fc3ffbbf2e069664",
                "128": "0284f2c06d938a6f78794814c687560a0aabab19fe5e6f30ede38e113b132a3cb9",
                "256": "03b99f475b68e5b4c0ba809cdecaae64eade2d9787aa123206f91cd61f76c01459",
                "512": "03d4db82ea19a44d35274de51f78af0a710925fe7d9e03620b84e3e9976e3ac2eb",
                "1024": "031fbd4ba801870871d46cf62228a1b748905ebc07d3b210daf48de229e683f2dc",
                "2048": "0276cedb9a3b160db6a158ad4e468d2437f021293204b3cd4bf6247970d8aff54b",
                "4096": "02fc6b89b403ee9eb8a7ed457cd3973638080d6e04ca8af7307c965c166b555ea2",
                "8192": "0320265583e916d3a305f0d2687fcf2cd4e3cd03a16ea8261fda309c3ec5721e21",
                "16384": "036e41de58fdff3cb1d8d713f48c63bc61fa3b3e1631495a444d178363c0d2ed50",
                "32768": "0365438f613f19696264300b069d1dad93f0c60a37536b72a8ab7c7366a5ee6c04",
                "65536": "02408426cfb6fc86341bac79624ba8708a4376b2d92debdf4134813f866eb57a8d",
                "131072": "031063e9f11c94dc778c473e968966eac0e70b7145213fbaff5f7a007e71c65f41",
                "262144": "02f2a3e808f9cd168ec71b7f328258d0c1dda250659c1aced14c7f5cf05aab4328",
                "524288": "038ac10de9f1ff9395903bb73077e94dbf91e9ef98fd77d9a2debc5f74c575bc86",
                "1048576": "0203eaee4db749b0fc7c49870d082024b2c31d889f9bc3b32473d4f1dfa3625788",
                "2097152": "033cdb9d36e1e82ae652b7b6a08e0204569ec7ff9ebf85d80a02786dc7fe00b04c",
                "4194304": "02c8b73f4e3a470ae05e5f2fe39984d41e9f6ae7be9f3b09c9ac31292e403ac512",
                "8388608": "025bbe0cfce8a1f4fbd7f3a0d4a09cb6badd73ef61829dc827aa8a98c270bc25b0",
                "16777216": "037eec3d1651a30a90182d9287a5c51386fe35d4a96839cf7969c6e2a03db1fc21",
                "33554432": "03280576b81a04e6abd7197f305506476f5751356b7643988495ca5c3e14e5c262",
                "67108864": "03268bfb05be1dbb33ab6e7e00e438373ca2c9b9abc018fdb452d0e1a0935e10d3",
                "134217728": "02573b68784ceba9617bbcc7c9487836d296aa7c628c3199173a841e7a19798020",
                "268435456": "0234076b6e70f7fbf755d2227ecc8d8169d662518ee3a1401f729e2a12ccb2b276",
                "536870912": "03015bd88961e2a466a2163bd4248d1d2b42c7c58a157e594785e7eb34d880efc9",
                "1073741824": "02c9b076d08f9020ebee49ac8ba2610b404d4e553a4f800150ceb539e9421aaeee",
                "2147483648": "034d592f4c366afddc919a509600af81b489a03caf4f7517c2b3f4f2b558f9a41a",
                "4294967296": "037c09ecb66da082981e4cbdb1ac65c0eb631fc75d85bed13efb2c6364148879b5",
                "8589934592": "02b4ebb0dda3b9ad83b39e2e31024b777cc0ac205a96b9a6cfab3edea2912ed1b3",
                "17179869184": "026cc4dacdced45e63f6e4f62edbc5779ccd802e7fabb82d5123db879b636176e9",
                "34359738368": "02b2cee01b7d8e90180254459b8f09bbea9aad34c3a2fd98c85517ecfc9805af75",
                "68719476736": "037a0c0d564540fc574b8bfa0253cca987b75466e44b295ed59f6f8bd41aace754",
                "137438953472": "021df6585cae9b9ca431318a713fd73dbb76b3ef5667957e8633bca8aaa7214fb6",
                "274877906944": "02b8f53dde126f8c85fa5bb6061c0be5aca90984ce9b902966941caf963648d53a",
                "549755813888": "029cc8af2840d59f1d8761779b2496623c82c64be8e15f9ab577c657c6dd453785",
                "1099511627776": "03e446fdb84fad492ff3a25fc1046fb9a93a5b262ebcd0151caa442ea28959a38a",
                "2199023255552": "02d6b25bd4ab599dd0818c55f75702fde603c93f259222001246569018842d3258",
                "4398046511104": "03397b522bb4e156ec3952d3f048e5a986c20a00718e5e52cd5718466bf494156a",
                "8796093022208": "02d1fb9e78262b5d7d74028073075b80bb5ab281edcfc3191061962c1346340f1e",
                "17592186044416": "030d3f2ad7a4ca115712ff7f140434f802b19a4c9b2dd1c76f3e8e80c05c6a9310",
                "35184372088832": "03e325b691f292e1dfb151c3fb7cad440b225795583c32e24e10635a80e4221c06",
                "70368744177664": "03bee8f64d88de3dee21d61f89efa32933da51152ddbd67466bef815e9f93f8fd1",
                "140737488355328": "0327244c9019a4892e1f04ba3bf95fe43b327479e2d57c25979446cc508cd379ed",
                "281474976710656": "02fb58522cd662f2f8b042f8161caae6e45de98283f74d4e99f19b0ea85e08a56d",
                "562949953421312": "02adde4b466a9d7e59386b6a701a39717c53f30c4810613c1b55e6b6da43b7bc9a",
                "1125899906842624": "038eeda11f78ce05c774f30e393cda075192b890d68590813ff46362548528dca9",
                "2251799813685248": "02ec13e0058b196db80f7079d329333b330dc30c000dbdd7397cbbc5a37a664c4f",
                "4503599627370496": "02d2d162db63675bd04f7d56df04508840f41e2ad87312a3c93041b494efe80a73",
                "9007199254740992": "0356969d6aef2bb40121dbd07c68b6102339f4ea8e674a9008bb69506795998f49",
                "18014398509481984": "02f4e667567ebb9f4e6e180a4113bb071c48855f657766bb5e9c776a880335d1d6",
                "36028797018963968": "0385b4fe35e41703d7a657d957c67bb536629de57b7e6ee6fe2130728ef0fc90b0",
                "72057594037927936": "02b2bc1968a6fddbcc78fb9903940524824b5f5bed329c6ad48a19b56068c144fd",
                "144115188075855872": "02e0dbb24f1d288a693e8a49bc14264d1276be16972131520cf9e055ae92fba19a",
                "288230376151711744": "03efe75c106f931a525dc2d653ebedddc413a2c7d8cb9da410893ae7d2fa7d19cc",
                "576460752303423488": "02c7ec2bd9508a7fc03f73c7565dc600b30fd86f3d305f8f139c45c404a52d958a",
                "1152921504606846976": "035a6679c6b25e68ff4e29d1c7ef87f21e0a8fc574f6a08c1aa45ff352c1d59f06",
                "2305843009213693952": "033cdc225962c052d485f7cfbf55a5b2367d200fe1fe4373a347deb4cc99e9a099",
                "4611686018427387904": "024a4b806cf413d14b294719090a9da36ba75209c7657135ad09bc65328fba9e6f",
                "9223372036854775808": "0377a6fe114e291a8d8e991627c38001c8305b23b9e98b1c7b1893f5cd0dda6cad"
            ]
        )
        
        // This keyset should be accepted
        #expect(keyset.validateKeys())
        
        // Verify we can handle large amounts
        let supportedAmounts = keyset.getSupportedAmounts()
        // Note: Some amounts are too large for Swift's Int type on 32-bit systems
        // The test vectors include amounts up to 2^63 which requires BigInteger support
        #expect(supportedAmounts.count >= 63) // At least 63 amounts should be parseable
        
        // Note: The largest amount (9223372036854775808) is larger than Int64.max
        // Swift cannot handle this as an integer literal, which demonstrates the limitation mentioned in the test vectors
        
        // Check some valid large amounts
        #expect(keyset.getPublicKey(for: 1073741824) == "02c9b076d08f9020ebee49ac8ba2610b404d4e553a4f800150ceb539e9421aaeee")
        #expect(keyset.getPublicKey(for: 2147483648) == "034d592f4c366afddc919a509600af81b489a03caf4f7517c2b3f4f2b558f9a41a")
        #expect(keyset.getPublicKey(for: 4294967296) == "037c09ecb66da082981e4cbdb1ac65c0eb631fc75d85bed13efb2c6364148879b5")
    }
}
