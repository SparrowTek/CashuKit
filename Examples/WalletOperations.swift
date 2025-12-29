/// # Wallet Operations
///
/// This example demonstrates common wallet operations: minting, sending,
/// receiving, and melting tokens using CashuKit.

import CashuKit
import Foundation

// MARK: - Minting Tokens

/// Mint new tokens by paying a Lightning invoice
func mintTokens(wallet: AppleCashuWallet, amount: Int) async throws {
    // Step 1: Request a mint quote
    let quote = try await wallet.requestMintQuote(amount: amount)
    
    print("Pay this Lightning invoice:")
    print(quote.request)
    print("\nQuote ID: \(quote.quote)")
    
    // Step 2: Wait for payment (poll or use callbacks in your app)
    var isPaid = false
    while !isPaid {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let status = try await wallet.checkMintQuoteStatus(quoteId: quote.quote)
        isPaid = status.paid
        
        if !isPaid {
            print("Waiting for payment...")
        }
    }
    
    // Step 3: Mint the tokens
    let proofs = try await wallet.mint(quoteId: quote.quote)
    
    print("\nMinted \(proofs.count) proofs!")
    print("New balance: \(await wallet.balance) sats")
}

// MARK: - Sending Tokens

/// Create a token to send to another user
func sendTokens(wallet: AppleCashuWallet, amount: Int, memo: String? = nil) async throws -> String {
    // Check balance
    let balance = await wallet.balance
    guard balance >= amount else {
        throw CashuError.insufficientBalance(required: amount, available: balance)
    }
    
    // Create the token
    let token = try await wallet.send(amount: amount, memo: memo)
    
    // Encode for sharing
    let tokenString = try wallet.encodeToken(token)
    
    print("Created token for \(amount) sats")
    print("Share this token:")
    print(tokenString)
    
    return tokenString
}

// MARK: - Receiving Tokens

/// Receive a token from another user
func receiveToken(wallet: AppleCashuWallet, tokenString: String) async throws {
    do {
        // The receive operation:
        // 1. Validates the token
        // 2. Checks if already spent
        // 3. Swaps for fresh proofs
        // 4. Stores in wallet
        
        let proofs = try await wallet.receive(token: tokenString)
        
        let amount = proofs.reduce(0) { $0 + $1.amount }
        print("Received \(amount) sats (\(proofs.count) proofs)")
        print("New balance: \(await wallet.balance) sats")
        
    } catch let error as CashuError {
        switch error {
        case .tokenAlreadySpent:
            print("Error: This token has already been redeemed")
        case .invalidToken(let reason):
            print("Error: Invalid token - \(reason)")
        default:
            print("Error: \(error.localizedDescription)")
        }
        throw error
    }
}

// MARK: - Melting Tokens (Paying Lightning)

/// Pay a Lightning invoice using wallet tokens
func payLightningInvoice(wallet: AppleCashuWallet, invoice: String) async throws {
    // Step 1: Get a quote
    let quote = try await wallet.requestMeltQuote(request: invoice)
    
    print("Invoice amount: \(quote.amount) sats")
    print("Fee reserve: \(quote.feeReserve) sats")
    print("Total needed: \(quote.amount + quote.feeReserve) sats")
    
    // Check balance
    let balance = await wallet.balance
    let needed = quote.amount + quote.feeReserve
    
    guard balance >= needed else {
        print("Insufficient balance: have \(balance), need \(needed)")
        throw CashuError.insufficientBalance(required: needed, available: balance)
    }
    
    // Step 2: Execute the melt
    let result = try await wallet.melt(quoteId: quote.quote)
    
    if result.paid {
        print("\nPayment successful!")
        
        if let preimage = result.paymentPreimage {
            print("Payment preimage: \(preimage)")
        }
        
        // Any unused fee is returned as change
        if let change = result.change, !change.isEmpty {
            let changeAmount = change.reduce(0) { $0 + $1.amount }
            print("Fee change returned: \(changeAmount) sats")
        }
        
        print("New balance: \(await wallet.balance) sats")
    } else {
        print("Payment pending or failed")
    }
}

// MARK: - Balance Operations

/// Check wallet balance and breakdown
func checkBalance(wallet: AppleCashuWallet) async {
    let balance = await wallet.balance
    print("Total balance: \(balance) sats")
    
    // Check available proofs
    if let proofs = try? await wallet.getAvailableProofs() {
        print("Number of proofs: \(proofs.count)")
        
        // Group by denomination
        let denominations = Dictionary(grouping: proofs) { $0.amount }
            .mapValues { $0.count }
            .sorted { $0.key > $1.key }
        
        print("\nDenomination breakdown:")
        for (amount, count) in denominations {
            print("  \(amount) sats: \(count) proofs")
        }
    }
}

// MARK: - Error Handling

/// Comprehensive error handling for wallet operations
func safeWalletOperation(wallet: AppleCashuWallet) async {
    do {
        let token = try await wallet.send(amount: 100)
        print("Success: \(try wallet.encodeToken(token))")
        
    } catch let error as CashuError {
        switch error {
        case .insufficientBalance(let required, let available):
            print("Not enough funds: need \(required), have \(available)")
            
        case .walletNotInitialized:
            print("Wallet not connected to a mint")
            
        case .networkError(let underlying):
            print("Network issue: \(underlying.localizedDescription)")
            // May want to retry
            
        case .mintError(let code, let message):
            print("Mint error (\(code)): \(message)")
            
        case .tokenAlreadySpent:
            print("Token was already spent")
            
        case .quoteExpired:
            print("Quote expired, request a new one")
            
        default:
            print("Error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
