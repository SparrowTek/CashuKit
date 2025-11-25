//
//  CashuTransactionListView.swift
//  CashuKit
//
//  SwiftUI view for displaying transaction history
//

import SwiftUI
import CoreCashu

/// Model for transaction display
public struct CashuTransaction: Identifiable {
    public let id = UUID()
    public let type: TransactionType
    public let amount: Int
    public let date: Date
    public let memo: String?
    public let status: TransactionStatus
    public let mintURL: String?
    
    public enum TransactionType: String {
        case mint
        case melt
        case send
        case receive
        
        var icon: String {
            switch self {
            case .mint: return "bolt.fill"
            case .melt: return "bolt.slash.fill"
            case .send: return "arrow.up.circle.fill"
            case .receive: return "arrow.down.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .mint, .receive: return .green
            case .melt, .send: return .red
            }
        }
    }
    
    public enum TransactionStatus: String {
        case pending
        case completed
        case failed
        
        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
}

/// SwiftUI view for transaction history
public struct CashuTransactionListView: View {
    @ObservedObject private var wallet: AppleCashuWallet
    @State private var transactions: [CashuTransaction] = []
    @State private var selectedTransaction: CashuTransaction?
    @State private var searchText = ""
    
    public init(wallet: AppleCashuWallet) {
        self.wallet = wallet
    }
    
    public var body: some View {
        NavigationView {
            List {
                if filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                        Section(header: sectionHeader(for: date)) {
                            ForEach(groupedTransactions[date] ?? []) { transaction in
                                TransactionRowView(transaction: transaction)
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                    }
                            }
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(InsetGroupedListStyle())
            #else
            .listStyle(SidebarListStyle())
            #endif
            .searchable(text: $searchText)
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: refreshTransactions) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(wallet.isLoading)
                }
            }
            .refreshable {
                await loadTransactions()
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
        }
        .task {
            await loadTransactions()
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Transactions")
                .font(.headline)
            
            Text("Your transaction history will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
    
    private func sectionHeader(for date: Date) -> some View {
        Text(formatSectionDate(date))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Computed Properties
    
    private var filteredTransactions: [CashuTransaction] {
        if searchText.isEmpty {
            return transactions
        }
        
        return transactions.filter { transaction in
            if let memo = transaction.memo {
                return memo.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }
    
    private var groupedTransactions: [Date: [CashuTransaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }
    
    // MARK: - Methods
    
    private func loadTransactions() async {
        // This would load from a proper transaction store
        // For now, generate sample data
        await MainActor.run {
            transactions = generateSampleTransactions()
        }
    }
    
    private func refreshTransactions() {
        Task {
            await loadTransactions()
        }
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private func generateSampleTransactions() -> [CashuTransaction] {
        // Sample data for preview
        return [
            CashuTransaction(
                type: .receive,
                amount: 1000,
                date: Date(),
                memo: "Test receive",
                status: .completed,
                mintURL: "https://mint.example.com"
            ),
            CashuTransaction(
                type: .send,
                amount: 500,
                date: Date().addingTimeInterval(-3600),
                memo: "Coffee payment",
                status: .completed,
                mintURL: "https://mint.example.com"
            ),
            CashuTransaction(
                type: .mint,
                amount: 5000,
                date: Date().addingTimeInterval(-86400),
                memo: "Lightning deposit",
                status: .pending,
                mintURL: "https://mint.example.com"
            )
        ]
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: CashuTransaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: transaction.type.icon)
                .font(.title3)
                .foregroundColor(transaction.type.color)
                .frame(width: 32, height: 32)
                .background(transaction.type.color.opacity(0.1))
                .clipShape(Circle())
                .accessibilityHidden(true)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.type.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if transaction.status == .pending {
                        Image(systemName: transaction.status.icon)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .accessibilityLabel("Pending")
                    }
                }

                if let memo = transaction.memo {
                    Text(memo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    Text(transaction.type == .send || transaction.type == .melt ? "-" : "+")
                    Text("\(transaction.amount)")
                        .fontWeight(.medium)
                }
                .foregroundColor(transaction.type.color)

                Text(formatTime(transaction.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let direction = (transaction.type == .send || transaction.type == .melt) ? "outgoing" : "incoming"
        let statusText = transaction.status == .pending ? ", pending" : ""
        let memoText = transaction.memo.map { ", \($0)" } ?? ""
        return "\(transaction.type.rawValue.capitalized) transaction, \(direction), \(transaction.amount) satoshis\(statusText)\(memoText)"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    let transaction: CashuTransaction
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Type")
                            .foregroundColor(.secondary)
                        Spacer()
                        Label(transaction.type.rawValue.capitalized, systemImage: transaction.type.icon)
                            .foregroundColor(transaction.type.color)
                    }
                    
                    HStack {
                        Text("Amount")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(transaction.amount) sats")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Label(transaction.status.rawValue.capitalized, systemImage: transaction.status.icon)
                    }
                }
                
                // Details section
                Section("Details") {
                    HStack {
                        Text("Date")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(transaction.date))
                    }
                    
                    if let memo = transaction.memo {
                        HStack(alignment: .top) {
                            Text("Memo")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(memo)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    if let mintURL = transaction.mintURL {
                        HStack {
                            Text("Mint")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(mintURL)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                
                // Actions section
                if transaction.status == .completed {
                    Section {
                        Button(action: shareTransaction) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        if transaction.type == .receive || transaction.type == .mint {
                            Button(action: viewProofs) {
                                Label("View Proofs", systemImage: "doc.text.magnifyingglass")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transaction Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func shareTransaction() {
        // Implement sharing functionality
    }
    
    private func viewProofs() {
        // Implement proof viewing
    }
}