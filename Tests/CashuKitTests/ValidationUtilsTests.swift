import Testing
@testable import CashuKit
import Foundation

@Suite("Validation Utils")
struct ValidationUtilsTests {
    
    // MARK: - Amount Validation Tests
    
    @Test
    func amountValidation() async throws {
        // Valid amounts
        let validResult = ValidationUtils.validateAmount(100)
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        
        let validMinResult = ValidationUtils.validateAmount(1)
        #expect(validMinResult.isValid)
        
        // Invalid amounts
        let invalidZeroResult = ValidationUtils.validateAmount(0)
        #expect(!invalidZeroResult.isValid)
        #expect(invalidZeroResult.errors.contains { $0.contains("at least 1") })
        
        let invalidNegativeResult = ValidationUtils.validateAmount(-10)
        #expect(!invalidNegativeResult.isValid)
        #expect(invalidNegativeResult.errors.contains { $0.contains("at least 1") })
        
        // Test with custom min/max
        let customMinResult = ValidationUtils.validateAmount(50, min: 100)
        #expect(!customMinResult.isValid)
        #expect(customMinResult.errors.contains { $0.contains("at least 100") })
        
        let customMaxResult = ValidationUtils.validateAmount(200, max: 100)
        #expect(!customMaxResult.isValid)
        #expect(customMaxResult.errors.contains { $0.contains("at most 100") })
    }
    
    @Test
    func positiveAmountValidation() async throws {
        #expect(ValidationUtils.isPositiveAmount(1))
        #expect(ValidationUtils.isPositiveAmount(100))
        #expect(ValidationUtils.isPositiveAmount(999999))
        
        #expect(!ValidationUtils.isPositiveAmount(0))
        #expect(!ValidationUtils.isPositiveAmount(-1))
        #expect(!ValidationUtils.isPositiveAmount(-100))
    }
    
    // MARK: - URL Validation Tests
    
    @Test
    func mintURLValidation() async throws {
        // Valid URLs
        let validHTTPSResult = ValidationUtils.validateMintURL("https://mint.example.com")
        #expect(validHTTPSResult.isValid)
        #expect(validHTTPSResult.errors.isEmpty)
        
        let validHTTPResult = ValidationUtils.validateMintURL("http://localhost:3338")
        #expect(validHTTPResult.isValid)
        
        let validWithPathResult = ValidationUtils.validateMintURL("https://mint.example.com/api/v1")
        #expect(validWithPathResult.isValid)
        
        // URLs without scheme (should be valid with auto-correction)
        let noSchemeResult = ValidationUtils.validateMintURL("mint.example.com")
        #expect(noSchemeResult.isValid)
        
        // Invalid URLs
        let emptyResult = ValidationUtils.validateMintURL("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("cannot be empty") })
        
        let whitespaceResult = ValidationUtils.validateMintURL("   ")
        #expect(!whitespaceResult.isValid)
        #expect(whitespaceResult.errors.contains { $0.contains("cannot be empty") })
        
        let invalidSchemeResult = ValidationUtils.validateMintURL("ftp://mint.example.com")
        #expect(!invalidSchemeResult.isValid)
        #expect(invalidSchemeResult.errors.contains { $0.contains("HTTP or HTTPS") })
        
        let noHostResult = ValidationUtils.validateMintURL("https://")
        #expect(!noHostResult.isValid)
        #expect(noHostResult.errors.contains { $0.contains("valid host") })
    }
    
    @Test
    func mintURLNormalization() async throws {
        // Test scheme addition
        let normalized1 = try ValidationUtils.normalizeMintURL("mint.example.com")
        #expect(normalized1 == "https://mint.example.com")
        
        let normalized2 = try ValidationUtils.normalizeMintURL("https://mint.example.com")
        #expect(normalized2 == "https://mint.example.com")
        
        // Test trailing slash removal
        let normalized3 = try ValidationUtils.normalizeMintURL("https://mint.example.com/")
        #expect(normalized3 == "https://mint.example.com")
        
        let normalized4 = try ValidationUtils.normalizeMintURL("mint.example.com/")
        #expect(normalized4 == "https://mint.example.com")
        
        // Test whitespace trimming
        let normalized5 = try ValidationUtils.normalizeMintURL("  mint.example.com  ")
        #expect(normalized5 == "https://mint.example.com")
        
        // Test invalid URL throws
        do {
            _ = try ValidationUtils.normalizeMintURL("")
            #expect(Bool(false), "Should have thrown an error for empty URL")
        } catch {
            #expect(error is CashuError)
        }
    }
    
    // MARK: - String Validation Tests
    
    @Test
    func hexStringValidation() async throws {
        // Valid hex strings
        let validLowercaseResult = ValidationUtils.validateHexString("deadbeef")
        #expect(validLowercaseResult.isValid)
        
        let validUppercaseResult = ValidationUtils.validateHexString("DEADBEEF")
        #expect(validUppercaseResult.isValid)
        
        let validMixedResult = ValidationUtils.validateHexString("DeAdBeEf")
        #expect(validMixedResult.isValid)
        
        let validLongResult = ValidationUtils.validateHexString("deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        #expect(validLongResult.isValid)
        
        // Invalid hex strings
        let emptyResult = ValidationUtils.validateHexString("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("cannot be empty") })
        
        let invalidCharsResult = ValidationUtils.validateHexString("deadbeefg")
        #expect(!invalidCharsResult.isValid)
        #expect(invalidCharsResult.errors.contains { $0.contains("Invalid hex string format") })
        
        let oddLengthResult = ValidationUtils.validateHexString("deadbee")
        #expect(!oddLengthResult.isValid)
        #expect(oddLengthResult.errors.contains { $0.contains("even length") })
    }
    
    @Test
    func nonEmptyStringValidation() async throws {
        // Valid strings
        let validResult = ValidationUtils.validateNonEmptyString("test", fieldName: "testField")
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        
        let validWithSpacesResult = ValidationUtils.validateNonEmptyString("  test  ", fieldName: "testField")
        #expect(validWithSpacesResult.isValid)
        
        // Invalid strings
        let emptyResult = ValidationUtils.validateNonEmptyString("", fieldName: "testField")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("testField cannot be empty") })
        
        let whitespaceResult = ValidationUtils.validateNonEmptyString("   ", fieldName: "testField")
        #expect(!whitespaceResult.isValid)
        #expect(whitespaceResult.errors.contains { $0.contains("testField cannot be empty") })
    }
    
    // MARK: - Proof Validation Tests
    
    @Test
    func proofValidation() async throws {
        // Valid proof
        let validProof = Proof(
            amount: 100,
            id: "test-id",
            secret: "test-secret",
            C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        )
        
        let validResult = ValidationUtils.validateProof(validProof)
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        
        // Invalid amount
        let invalidAmountProof = Proof(amount: 0, id: "test-id", secret: "test-secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let invalidAmountResult = ValidationUtils.validateProof(invalidAmountProof)
        #expect(!invalidAmountResult.isValid)
        #expect(invalidAmountResult.errors.contains { $0.contains("at least 1") })
        
        // Empty secret
        let emptySecretProof = Proof(amount: 100, id: "test-id", secret: "", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let emptySecretResult = ValidationUtils.validateProof(emptySecretProof)
        #expect(!emptySecretResult.isValid)
        #expect(emptySecretResult.errors.contains { $0.contains("secret cannot be empty") })
        
        // Empty ID
        let emptyIDProof = Proof(amount: 100, id: "", secret: "test-secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let emptyIDResult = ValidationUtils.validateProof(emptyIDProof)
        #expect(!emptyIDResult.isValid)
        #expect(emptyIDResult.errors.contains { $0.contains("id cannot be empty") })
        
        // Invalid C value
        let invalidCProof = Proof(amount: 100, id: "test-id", secret: "test-secret", C: "invalid-hex")
        let invalidCResult = ValidationUtils.validateProof(invalidCProof)
        #expect(!invalidCResult.isValid)
        #expect(invalidCResult.errors.contains { $0.contains("Invalid C value") })
    }
    
    @Test
    func proofArrayValidation() async throws {
        let validProofs = [
            Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 200, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        ]
        
        let validResult = ValidationUtils.validateProofs(validProofs)
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        
        // Empty array
        let emptyResult = ValidationUtils.validateProofs([])
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("cannot be empty") })
        
        // Mixed valid/invalid proofs
        let mixedProofs = [
            Proof(amount: 100, id: "id1", secret: "secret1", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"),
            Proof(amount: 0, id: "id2", secret: "secret2", C: "abcdef1234567890deadbeef1234567890abcdef1234567890abcdef1234567890")
        ]
        
        let mixedResult = ValidationUtils.validateProofs(mixedProofs)
        #expect(!mixedResult.isValid)
        #expect(mixedResult.errors.contains { $0.contains("index 1") })
    }
    
    // MARK: - Token Validation Tests
    
    @Test
    func tokenValidation() async throws {
        // Valid token
        let validProof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let validEntry = TokenEntry(mint: "https://mint.example.com", proofs: [validProof])
        let validToken = CashuToken(token: [validEntry], unit: "sat", memo: nil)
        
        let validResult = ValidationUtils.validateCashuToken(validToken)
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        
        // Empty token entries
        let emptyToken = CashuToken(token: [], unit: "sat", memo: nil)
        let emptyResult = ValidationUtils.validateCashuToken(emptyToken)
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("cannot be empty") })
        
        // Invalid token entry
        let invalidEntry = TokenEntry(mint: "invalid-url", proofs: [validProof])
        let invalidToken = CashuToken(token: [invalidEntry], unit: "sat", memo: nil)
        let invalidResult = ValidationUtils.validateCashuToken(invalidToken)
        #expect(!invalidResult.isValid)
        #expect(invalidResult.errors.contains { $0.contains("Invalid mint URL") })
    }
    
    @Test
    func tokenEntryValidation() async throws {
        // Valid token entry
        let validProof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let validEntry = TokenEntry(mint: "https://mint.example.com", proofs: [validProof])
        
        let validResult = ValidationUtils.validateTokenEntry(validEntry)
        #expect(validResult.isValid)
        #expect(validResult.errors.isEmpty)
        
        // Invalid mint URL
        let invalidMintEntry = TokenEntry(mint: "invalid-url", proofs: [validProof])
        let invalidMintResult = ValidationUtils.validateTokenEntry(invalidMintEntry)
        #expect(!invalidMintResult.isValid)
        #expect(invalidMintResult.errors.contains { $0.contains("Invalid mint URL") })
        
        // Invalid proofs
        let invalidProof = Proof(amount: 0, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        let invalidProofEntry = TokenEntry(mint: "https://mint.example.com", proofs: [invalidProof])
        let invalidProofResult = ValidationUtils.validateTokenEntry(invalidProofEntry)
        #expect(!invalidProofResult.isValid)
        #expect(invalidProofResult.errors.contains { $0.contains("Invalid proofs") })
    }
    
    // MARK: - Payment Request Validation Tests
    
    @Test
    func paymentRequestValidation() async throws {
        // Valid Lightning invoice
        let validInvoice = "lnbc1u1pw5qrxfpp5..."
        let validResult = ValidationUtils.validatePaymentRequest(validInvoice)
        #expect(validResult.isValid)
        
        // Valid testnet invoice
        let validTestnetInvoice = "lntb1u1pw5qrxfpp5..."
        let validTestnetResult = ValidationUtils.validatePaymentRequest(validTestnetInvoice)
        #expect(validTestnetResult.isValid)
        
        // Empty payment request
        let emptyResult = ValidationUtils.validatePaymentRequest("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("cannot be empty") })
        
        // Whitespace only
        let whitespaceResult = ValidationUtils.validatePaymentRequest("   ")
        #expect(!whitespaceResult.isValid)
        #expect(whitespaceResult.errors.contains { $0.contains("cannot be empty") })
        
        // Invalid Lightning invoice format
        let invalidFormatResult = ValidationUtils.validatePaymentRequest("invalid-invoice")
        #expect(!invalidFormatResult.isValid)
        #expect(invalidFormatResult.errors.contains { $0.contains("Invalid Lightning invoice format") })
    }
    
    // MARK: - Unit Validation Tests
    
    @Test
    func unitValidation() async throws {
        // Valid units
        let validUnits = ["sat", "msat", "btc", "usd", "eur", "gbp", "jpy", "cad", "aud", "chf"]
        
        for unit in validUnits {
            let result = ValidationUtils.validateUnit(unit)
            #expect(result.isValid, "Unit \(unit) should be valid")
            #expect(result.errors.isEmpty, "Unit \(unit) should have no errors")
        }
        
        // Case insensitive
        let uppercaseResult = ValidationUtils.validateUnit("SAT")
        #expect(uppercaseResult.isValid)
        
        let mixedCaseResult = ValidationUtils.validateUnit("Btc")
        #expect(mixedCaseResult.isValid)
        
        // Invalid units
        let emptyResult = ValidationUtils.validateUnit("")
        #expect(!emptyResult.isValid)
        #expect(emptyResult.errors.contains { $0.contains("cannot be empty") })
        
        let whitespaceResult = ValidationUtils.validateUnit("   ")
        #expect(!whitespaceResult.isValid)
        #expect(whitespaceResult.errors.contains { $0.contains("cannot be empty") })
        
        let unsupportedResult = ValidationUtils.validateUnit("dogecoin")
        #expect(!unsupportedResult.isValid)
        #expect(unsupportedResult.errors.contains { $0.contains("Unsupported unit") })
    }
    
    // MARK: - Validation Helper Tests
    
    @Test
    func validationResult() async throws {
        // Test ValidationResult with no errors
        let successResult = ValidationResult(isValid: true, errors: [])
        #expect(successResult.isValid)
        #expect(successResult.errors.isEmpty)
        #expect(successResult.firstError == nil)
        #expect(successResult.allErrors.isEmpty)
        
        // Test ValidationResult with errors
        let failureResult = ValidationResult(isValid: false, errors: ["Error 1", "Error 2"])
        #expect(!failureResult.isValid)
        #expect(failureResult.errors.count == 2)
        #expect(failureResult.firstError == "Error 1")
        #expect(failureResult.allErrors == "Error 1; Error 2")
    }
    
    @Test
    func validationConvenienceFunctions() async throws {
        // Test validateAndThrow with valid input
        let validProof = Proof(amount: 100, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        
        try validateAndThrow(validProof, validator: ValidationUtils.validateProof, error: CashuError.invalidProofSet)
        
        // Test validateAndThrow with invalid input
        let invalidProof = Proof(amount: 0, id: "id", secret: "secret", C: "deadbeef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        
        do {
            try validateAndThrow(invalidProof, validator: ValidationUtils.validateProof, error: CashuError.invalidProofSet)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is CashuError)
        }
        
        // Test validateAmountAndThrow with valid amount
        try validateAmountAndThrow(100)
        
        // Test validateAmountAndThrow with invalid amount
        do {
            try validateAmountAndThrow(0)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error is CashuError)
        }
    }
}
