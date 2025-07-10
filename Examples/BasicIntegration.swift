//
//  BasicIntegration.swift
//  CashuKit Examples
//
//  Basic integration example showing how to use CashuKit in your iOS app
//

import Foundation
import CashuKit

// MARK: - Basic Wallet Manager

/// Example wallet manager that demonstrates basic CashuKit integration
@MainActor
class BasicWalletManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var wallet: CashuWallet?
    @Published var balance: Int = 0
    @Published var isInitialized: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration
    
    private let mintURL = "https://mint.example.com"
    private let unit = "sat"
    
    // MARK: - Lifecycle
    
    init() {
        Task {
            await setupWallet()
        }
    }
    
    // MARK: - Wallet Setup
    
    /// Setup and initialize the wallet
    private func setupWallet() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create wallet
            wallet = await CashuKit.createWallet(mintURL: mintURL, unit: unit)
            
            guard let wallet = wallet else {
                throw CashuError.walletCreationFailed
            }
            
            // Initialize wallet
            try await wallet.initialize()
            
            // Update state
            isInitialized = true
            
            // Start balance monitoring
            await startBalanceMonitoring()
            
        } catch {
            errorMessage = error.localizedDescription
            isInitialized = false
        }
        
        isLoading = false
    }
    
    /// Start monitoring balance changes
    private func startBalanceMonitoring() async {
        guard let wallet = wallet else { return }
        
        // Monitor balance changes in real-time
        Task {
            for await update in wallet.getBalanceStream() {
                if update.balanceChanged {
                    await MainActor.run {
                        self.balance = update.newBalance
                    }
                }
                
                if let error = update.error {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Wallet Operations
    
    /// Refresh wallet balance
    func refreshBalance() async {
        guard let wallet = wallet, isInitialized else { return }
        
        do {
            let currentBalance = try await wallet.balance
            balance = currentBalance
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Mint tokens from Lightning invoice
    func mint(amount: Int, paymentRequest: String) async -> Bool {
        guard let wallet = wallet, isInitialized else {
            errorMessage = "Wallet not initialized"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await wallet.mint(
                amount: amount,
                paymentRequest: paymentRequest
            )
            
            print("Minted \(amount) tokens successfully")
            await refreshBalance()
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        
        isLoading = false
    }
    
    /// Send tokens to another wallet
    func send(amount: Int, memo: String? = nil) async -> String? {
        guard let wallet = wallet, isInitialized else {
            errorMessage = "Wallet not initialized"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let token = try await wallet.send(amount: amount, memo: memo)
            let serializedToken = try await wallet.exportToken(amount: amount, memo: memo)
            
            print("Created token for \(amount) tokens")
            await refreshBalance()
            return serializedToken
            
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
        
        isLoading = false
    }
    
    /// Receive tokens from another wallet
    func receive(serializedToken: String) async -> Bool {
        guard let wallet = wallet, isInitialized else {
            errorMessage = "Wallet not initialized"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let proofs = try await wallet.importToken(serializedToken)
            print("Received \(proofs.count) proofs")
            await refreshBalance()
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        
        isLoading = false
    }
    
    /// Melt tokens (spend via Lightning)
    func melt(paymentRequest: String) async -> Bool {
        guard let wallet = wallet, isInitialized else {
            errorMessage = "Wallet not initialized"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await wallet.melt(paymentRequest: paymentRequest)
            print("Melted tokens successfully")
            await refreshBalance()
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        
        isLoading = false
    }
    
    /// Get wallet statistics
    func getStatistics() async -> WalletStatistics? {
        guard let wallet = wallet, isInitialized else { return nil }
        
        do {
            return try await wallet.getStatistics()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Sync wallet with mint
    func sync() async {
        guard let wallet = wallet, isInitialized else { return }
        
        isLoading = true
        
        do {
            try await wallet.sync()
            await refreshBalance()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - SwiftUI View Example

#if canImport(SwiftUI)
import SwiftUI

/// Example SwiftUI view that uses CashuKit
struct WalletView: View {
    @StateObject private var walletManager = BasicWalletManager()
    @State private var showingMintSheet = false
    @State private var showingSendSheet = false
    @State private var showingReceiveSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Wallet Status
                walletStatusView
                
                // Balance Display
                balanceView
                
                // Action Buttons
                actionButtonsView
                
                // Error Message
                if let errorMessage = walletManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Cashu Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sync") {
                        Task {
                            await walletManager.sync()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMintSheet) {
            MintTokensView(walletManager: walletManager)
        }
        .sheet(isPresented: $showingSendSheet) {
            SendTokensView(walletManager: walletManager)
        }
        .sheet(isPresented: $showingReceiveSheet) {
            ReceiveTokensView(walletManager: walletManager)
        }
    }
    
    // MARK: - View Components
    
    private var walletStatusView: some View {
        HStack {
            Circle()
                .fill(walletManager.isInitialized ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            Text(walletManager.isInitialized ? "Connected" : "Disconnected")
                .font(.caption)
        }
    }
    
    private var balanceView: some View {
        VStack {
            Text("\(walletManager.balance)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("sats")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button("Mint Tokens") {
                showingMintSheet = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!walletManager.isInitialized || walletManager.isLoading)
            
            HStack(spacing: 12) {
                Button("Send") {
                    showingSendSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(!walletManager.isInitialized || walletManager.isLoading)
                
                Button("Receive") {
                    showingReceiveSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(!walletManager.isInitialized || walletManager.isLoading)
            }
        }
    }
}

// MARK: - Sheet Views

struct MintTokensView: View {
    @ObservedObject var walletManager: BasicWalletManager
    @State private var amount: String = ""
    @State private var paymentRequest: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Amount (sats)", text: $amount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Lightning Invoice", text: $paymentRequest, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Button("Mint Tokens") {
                    Task {
                        guard let amountInt = Int(amount) else { return }
                        let success = await walletManager.mint(
                            amount: amountInt,
                            paymentRequest: paymentRequest
                        )
                        if success {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount.isEmpty || paymentRequest.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Mint Tokens")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct SendTokensView: View {
    @ObservedObject var walletManager: BasicWalletManager
    @State private var amount: String = ""
    @State private var memo: String = ""
    @State private var generatedToken: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Amount (sats)", text: $amount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Memo (optional)", text: $memo)
                    .textFieldStyle(.roundedBorder)
                
                Button("Create Token") {
                    Task {
                        guard let amountInt = Int(amount) else { return }
                        if let token = await walletManager.send(
                            amount: amountInt,
                            memo: memo.isEmpty ? nil : memo
                        ) {
                            generatedToken = token
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount.isEmpty)
                
                if !generatedToken.isEmpty {
                    VStack {
                        Text("Generated Token:")
                            .font(.headline)
                        
                        Text(generatedToken)
                            .font(.caption)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .onTapGesture {
                                UIPasteboard.general.string = generatedToken
                            }
                        
                        Text("Tap to copy")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Send Tokens")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct ReceiveTokensView: View {
    @ObservedObject var walletManager: BasicWalletManager
    @State private var tokenString: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Paste token here", text: $tokenString, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                Button("Receive Token") {
                    Task {
                        let success = await walletManager.receive(serializedToken: tokenString)
                        if success {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(tokenString.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Receive Tokens")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

#endif

// MARK: - Command Line Example

/// Example command line interface for CashuKit
class CommandLineWallet {
    private var wallet: CashuWallet?
    private let mintURL: String
    
    init(mintURL: String) {
        self.mintURL = mintURL
    }
    
    func run() async {
        print("🪙 CashuKit Command Line Wallet")
        print("Connecting to mint: \(mintURL)")
        
        do {
            // Setup wallet
            wallet = await CashuKit.createWallet(mintURL: mintURL)
            guard let wallet = wallet else {
                print("❌ Failed to create wallet")
                return
            }
            
            try await wallet.initialize()
            print("✅ Wallet initialized successfully")
            
            // Show initial balance
            let balance = try await wallet.balance
            print("💰 Current balance: \(balance) sats")
            
            // Example operations
            await demonstrateOperations()
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    private func demonstrateOperations() async {
        guard let wallet = wallet else { return }
        
        print("\n📊 Wallet Statistics:")
        do {
            let stats = try await wallet.getStatistics()
            print("- Total balance: \(stats.totalBalance) sats")
            print("- Proof count: \(stats.proofCount)")
            print("- Spent proofs: \(stats.spentProofCount)")
            print("- Keysets: \(stats.keysetCount)")
        } catch {
            print("❌ Failed to get statistics: \(error)")
        }
        
        print("\n🔧 Denomination Breakdown:")
        do {
            let breakdown = try await wallet.getDenominationBreakdown()
            print("- Total value: \(breakdown.totalValue) sats")
            print("- Total proofs: \(breakdown.totalProofs)")
            print("- Denominations: \(breakdown.denominations)")
        } catch {
            print("❌ Failed to get denomination breakdown: \(error)")
        }
    }
}

// MARK: - Example Usage

/// Example of how to use CashuKit in different contexts
public struct CashuKitExamples {
    
    /// Example: Basic wallet setup
    public static func basicWalletSetup() async throws {
        // Create and initialize wallet
        let wallet = await CashuKit.createWallet(mintURL: "https://mint.example.com")
        try await wallet.initialize()
        
        // Check balance
        let balance = try await wallet.balance
        print("Balance: \(balance) sats")
    }
    
    /// Example: Mint tokens
    public static func mintTokensExample() async throws {
        let wallet = await CashuKit.createWallet(mintURL: "https://mint.example.com")
        try await wallet.initialize()
        
        // Mint 1000 sats
        let result = try await wallet.mint(
            amount: 1000,
            paymentRequest: "lnbc10u1p3..."
        )
        
        print("Minted \(result.proofs.count) proofs")
    }
    
    /// Example: Send and receive tokens
    public static func sendReceiveExample() async throws {
        let wallet1 = await CashuKit.createWallet(mintURL: "https://mint.example.com")
        let wallet2 = await CashuKit.createWallet(mintURL: "https://mint.example.com")
        
        try await wallet1.initialize()
        try await wallet2.initialize()
        
        // Send 500 sats from wallet1
        let token = try await wallet1.send(amount: 500, memo: "Payment")
        let serializedToken = try await wallet1.exportToken(amount: 500, memo: "Payment")
        
        // Receive in wallet2
        let proofs = try await wallet2.importToken(serializedToken)
        print("Received \(proofs.count) proofs")
    }
    
    /// Example: Balance monitoring
    public static func balanceMonitoringExample() async throws {
        let wallet = await CashuKit.createWallet(mintURL: "https://mint.example.com")
        try await wallet.initialize()
        
        // Monitor balance changes
        Task {
            for await update in wallet.getBalanceStream() {
                if update.balanceChanged {
                    print("Balance changed: \(update.previousBalance) → \(update.newBalance)")
                }
            }
        }
    }
    
    /// Example: Advanced configuration
    public static func advancedConfigurationExample() async throws {
        let config = WalletConfiguration(
            mintURL: "https://mint.example.com",
            unit: "sat",
            retryAttempts: 5,
            retryDelay: 2.0,
            operationTimeout: 60.0
        )
        
        let wallet = await CashuKit.createWallet(configuration: config)
        try await wallet.initialize()
        
        // Use wallet with custom configuration
        let balance = try await wallet.balance
        print("Balance: \(balance) sats")
    }
}