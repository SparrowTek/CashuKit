//
//  MintSelectionView.swift
//  CashuKit
//
//  SwiftUI view for selecting and managing Cashu mints
//

import SwiftUI
import CoreCashu

/// Model for mint display
public struct MintInfo: Identifiable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let description: String?
    public let pubkey: String?
    public let nuts: [String]
    public let isOnline: Bool
    public let lastChecked: Date
    
    public init(
        url: URL,
        name: String,
        description: String? = nil,
        pubkey: String? = nil,
        nuts: [String] = [],
        isOnline: Bool = true,
        lastChecked: Date = Date()
    ) {
        self.url = url
        self.name = name
        self.description = description
        self.pubkey = pubkey
        self.nuts = nuts
        self.isOnline = isOnline
        self.lastChecked = lastChecked
    }
}

/// SwiftUI view for mint selection and management
public struct MintSelectionView: View {
    @ObservedObject private var wallet: AppleCashuWallet
    @State private var mints: [MintInfo] = []
    @State private var selectedMint: MintInfo?
    @State private var showingAddMint = false
    @State private var newMintURL = ""
    @State private var isCheckingMint = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    public init(wallet: AppleCashuWallet) {
        self.wallet = wallet
    }
    
    public var body: some View {
        NavigationView {
            List {
                // Current mint section
                if let currentURL = wallet.currentMintURL {
                    Section("Current Mint") {
                        CurrentMintRow(
                            url: currentURL,
                            isConnected: wallet.isConnected,
                            onDisconnect: disconnectMint
                        )
                    }
                }
                
                // Available mints section
                Section("Available Mints") {
                    if mints.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "server.rack")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No mints added")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical)
                            Spacer()
                        }
                    } else {
                        ForEach(mints) { mint in
                            MintRowView(
                                mint: mint,
                                isSelected: wallet.currentMintURL == mint.url,
                                onSelect: { selectMint(mint) }
                            )
                        }
                        .onDelete(perform: deleteMints)
                    }
                }
                
                // Popular mints section (optional)
                Section("Popular Mints") {
                    ForEach(popularMints) { mint in
                        MintRowView(
                            mint: mint,
                            isSelected: wallet.currentMintURL == mint.url,
                            onSelect: { selectMint(mint) }
                        )
                    }
                }
            }
            #if os(iOS)
            .listStyle(InsetGroupedListStyle())
            #else
            .listStyle(SidebarListStyle())
            #endif
            .navigationTitle("Mints")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingAddMint = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMint) {
                AddMintView(
                    mintURL: $newMintURL,
                    isChecking: $isCheckingMint,
                    onAdd: addMint,
                    onCancel: { showingAddMint = false }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await loadMints()
        }
    }
    
    // MARK: - Methods
    
    private func loadMints() async {
        // Load saved mints from storage
        // For now, use sample data
        await MainActor.run {
            mints = []
        }
    }
    
    private func selectMint(_ mint: MintInfo) {
        Task {
            do {
                try await wallet.connect(to: mint.url)
                selectedMint = mint
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func disconnectMint() {
        Task {
            await wallet.disconnect()
            selectedMint = nil
        }
    }
    
    private func addMint() {
        guard let url = URL(string: newMintURL) else {
            showError("Invalid URL")
            return
        }
        
        isCheckingMint = true
        
        Task {
            do {
                // Check if mint is reachable
                try await wallet.connect(to: url)
                
                let mint = MintInfo(
                    url: url,
                    name: url.host ?? "Unknown Mint",
                    isOnline: true
                )
                
                await MainActor.run {
                    mints.append(mint)
                    newMintURL = ""
                    showingAddMint = false
                    isCheckingMint = false
                }
            } catch {
                await MainActor.run {
                    isCheckingMint = false
                    showError("Failed to connect to mint: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteMints(at offsets: IndexSet) {
        mints.remove(atOffsets: offsets)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    // MARK: - Sample Data
    
    private var popularMints: [MintInfo] {
        [
            MintInfo(
                url: URL(string: "https://mint.minibits.cash")!,
                name: "Minibits",
                description: "Popular Cashu mint",
                nuts: ["NUT-00", "NUT-01", "NUT-02", "NUT-03", "NUT-04", "NUT-05"],
                isOnline: true
            ),
            MintInfo(
                url: URL(string: "https://legend.lnbits.com")!,
                name: "LNbits Legend",
                description: "LNbits demo mint",
                nuts: ["NUT-00", "NUT-01", "NUT-02", "NUT-03"],
                isOnline: true
            )
        ]
    }
}

// MARK: - Current Mint Row

struct CurrentMintRow: View {
    let url: URL
    let isConnected: Bool
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(url.host ?? "Unknown")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(isConnected ? "Connected" : "Connecting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDisconnect) {
                Text("Disconnect")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mint Row View

struct MintRowView: View {
    let mint: MintInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mint.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    if let description = mint.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        // Online status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(mint.isOnline ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            
                            Text(mint.isOnline ? "Online" : "Offline")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // NUT support
                        if !mint.nuts.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("\(mint.nuts.count) NUTs")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Mint View

struct AddMintView: View {
    @Binding var mintURL: String
    @Binding var isChecking: Bool
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Mint URL", text: $mintURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        .disabled(isChecking)
                } header: {
                    Text("Enter Mint URL")
                } footer: {
                    Text("Example: https://mint.example.com")
                        .font(.caption)
                }
                
                if isChecking {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Checking mint...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Mint")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isChecking)
                }
                
                ToolbarItem(placement: .automatic) {
                    Button("Add", action: onAdd)
                        .disabled(mintURL.isEmpty || isChecking)
                }
            }
        }
    }
}