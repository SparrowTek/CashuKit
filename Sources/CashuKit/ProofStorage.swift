//
//  ProofStorage.swift
//  CashuKit
//
//  Proof management and storage for CashuWallet
//

import Foundation

// MARK: - Proof Storage Protocol

/// Protocol for proof storage implementations
public protocol ProofStorage: Sendable {
    /// Store proofs in the storage
    func store(_ proofs: [Proof]) async throws
    
    /// Retrieve all proofs from storage
    func retrieveAll() async throws -> [Proof]
    
    /// Retrieve proofs by keyset ID
    func retrieve(keysetID: String) async throws -> [Proof]
    
    /// Remove proofs from storage
    func remove(_ proofs: [Proof]) async throws
    
    /// Clear all proofs from storage
    func clear() async throws
    
    /// Check if a proof exists in storage
    func contains(_ proof: Proof) async throws -> Bool
    
    /// Get total count of proofs
    func count() async throws -> Int

    // Transactional lifecycle (optional for durable stores; in-memory no-op acceptable)
    func markAsPendingSpent(_ proofs: [Proof]) async throws
    func finalizePendingSpent(_ proofs: [Proof]) async throws
    func rollbackPendingSpent(_ proofs: [Proof]) async throws
}

// MARK: - In-Memory Proof Storage

/// In-memory implementation of proof storage
/// Thread-safe using actor isolation
@CashuActor
public final class InMemoryProofStorage: ProofStorage, Sendable {
    private var proofs: Set<ProofWrapper> = []
    private var pendingSpent: Set<ProofWrapper> = []
    
    public nonisolated init() {}
    
    public func store(_ proofs: [Proof]) async throws {
        let wrappers = proofs.map(ProofWrapper.init)
        self.proofs.formUnion(wrappers)
    }
    
    public func retrieveAll() async throws -> [Proof] {
        return Array(proofs.map(\.proof))
    }
    
    public func retrieve(keysetID: String) async throws -> [Proof] {
        return proofs
            .filter { $0.proof.id == keysetID }
            .map(\.proof)
    }
    
    public func remove(_ proofs: [Proof]) async throws {
        let wrappersToRemove = Set(proofs.map(ProofWrapper.init))
        self.proofs.subtract(wrappersToRemove)
    }
    
    public func clear() async throws {
        proofs.removeAll()
    }
    
    public func contains(_ proof: Proof) async throws -> Bool {
        return proofs.contains(ProofWrapper(proof))
    }
    
    public func count() async throws -> Int {
        return proofs.count
    }

    // MARK: - Transactional lifecycle
    public func markAsPendingSpent(_ proofs: [Proof]) async throws {
        pendingSpent.formUnion(proofs.map(ProofWrapper.init))
    }

    public func finalizePendingSpent(_ proofs: [Proof]) async throws {
        let wrappers = Set(proofs.map(ProofWrapper.init))
        pendingSpent.subtract(wrappers)
        // In in-memory storage, spent vs unspent is coordinated by ProofManager; nothing else to do here
    }

    public func rollbackPendingSpent(_ proofs: [Proof]) async throws {
        let wrappers = Set(proofs.map(ProofWrapper.init))
        pendingSpent.subtract(wrappers)
    }
}

// MARK: - Proof Wrapper

/// Wrapper to make Proof hashable and equatable for Set operations
private struct ProofWrapper: Hashable, Sendable {
    let proof: Proof
    
    init(_ proof: Proof) {
        self.proof = proof
    }
    
    static func == (lhs: ProofWrapper, rhs: ProofWrapper) -> Bool {
        return lhs.proof.secret == rhs.proof.secret &&
               lhs.proof.C == rhs.proof.C &&
               lhs.proof.id == rhs.proof.id &&
               lhs.proof.amount == rhs.proof.amount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(proof.secret)
        hasher.combine(proof.C)
        hasher.combine(proof.id)
        hasher.combine(proof.amount)
    }
}

// MARK: - Proof Manager

/// Manages proof operations and validation
@CashuActor
public final class ProofManager: Sendable {
    private let storage: any ProofStorage
    private var spentProofs: Set<ProofWrapper> = []
    
    public nonisolated init(storage: any ProofStorage = InMemoryProofStorage()) {
        self.storage = storage
    }
    
    // MARK: - Proof Operations
    
    /// Add new proofs to storage
    public func addProofs(_ proofs: [Proof]) async throws {
        guard !proofs.isEmpty else { return }
        
        // Validate proofs before adding
        try await validateProofs(proofs)
        
        // Check for duplicates
        for proof in proofs {
            if try await storage.contains(proof) {
                throw CashuError.proofAlreadySpent
            }
        }
        
        try await storage.store(proofs)
    }
    
    /// Get all available (unspent) proofs
    public func getAvailableProofs() async throws -> [Proof] {
        let allProofs = try await storage.retrieveAll()
        return allProofs.filter { !spentProofs.contains(ProofWrapper($0)) }
    }
    
    /// Get available proofs for a specific keyset
    public func getAvailableProofs(keysetID: String) async throws -> [Proof] {
        let keysetProofs = try await storage.retrieve(keysetID: keysetID)
        return keysetProofs.filter { !spentProofs.contains(ProofWrapper($0)) }
    }
    
    /// Mark proofs as spent
    public func markAsSpent(_ proofs: [Proof]) async throws {
        let wrappers = proofs.map(ProofWrapper.init)
        spentProofs.formUnion(wrappers)
    }

    // Transactional lifecycle helpers
    public func markAsPendingSpent(_ proofs: [Proof]) async throws {
        try await storage.markAsPendingSpent(proofs)
    }
    public func finalizePendingSpent(_ proofs: [Proof]) async throws {
        try await storage.finalizePendingSpent(proofs)
    }
    public func rollbackPendingSpent(_ proofs: [Proof]) async throws {
        try await storage.rollbackPendingSpent(proofs)
    }
    
    /// Remove proofs from storage (after successful spending)
    public func removeProofs(_ proofs: [Proof]) async throws {
        try await storage.remove(proofs)
        let wrappers = proofs.map(ProofWrapper.init)
        spentProofs.subtract(wrappers)
    }
    
    /// Get total balance from available proofs
    public func getTotalBalance() async throws -> Int {
        let availableProofs = try await getAvailableProofs()
        return availableProofs.reduce(0) { $0 + $1.amount }
    }
    
    /// Get balance by keyset
    public func getBalance(keysetID: String) async throws -> Int {
        let keysetProofs = try await getAvailableProofs(keysetID: keysetID)
        return keysetProofs.reduce(0) { $0 + $1.amount }
    }
    
    /// Select proofs for spending a specific amount
    public func selectProofs(amount: Int) async throws -> [Proof] {
        let availableProofs = try await getAvailableProofs()
        
        guard !availableProofs.isEmpty else {
            throw CashuError.noSpendableProofs
        }
        
        let totalBalance = availableProofs.reduce(0) { $0 + $1.amount }
        guard totalBalance >= amount else {
            throw CashuError.balanceInsufficient
        }
        
        return try selectOptimalProofs(from: availableProofs, targetAmount: amount)
    }
    
    /// Select proofs from a specific keyset
    public func selectProofs(amount: Int, keysetID: String) async throws -> [Proof] {
        let keysetProofs = try await getAvailableProofs(keysetID: keysetID)
        
        guard !keysetProofs.isEmpty else {
            throw CashuError.noSpendableProofs
        }
        
        let keysetBalance = keysetProofs.reduce(0) { $0 + $1.amount }
        guard keysetBalance >= amount else {
            throw CashuError.balanceInsufficient
        }
        
        return try selectOptimalProofs(from: keysetProofs, targetAmount: amount)
    }
    
    /// Clear all proofs and spent tracking
    public func clearAll() async throws {
        try await storage.clear()
        spentProofs.removeAll()
    }
    
    /// Get proof count
    public func getProofCount() async throws -> Int {
        try await storage.count()
    }
    
    /// Get spent proof count
    public func getSpentProofCount() async -> Int {
        spentProofs.count
    }
    
    // MARK: - Private Methods
    
    /// Validate proofs before storage
    private func validateProofs(_ proofs: [Proof]) async throws {
        for proof in proofs {
            guard proof.amount > 0 else {
                throw CashuError.invalidAmount
            }
            
            guard !proof.secret.isEmpty else {
                throw CashuError.missingRequiredField("secret")
            }
            
            guard !proof.C.isEmpty else {
                throw CashuError.missingRequiredField("C")
            }
            
            guard !proof.id.isEmpty else {
                throw CashuError.missingRequiredField("id")
            }
            
            // Validate hex strings
            guard Data(hexString: proof.C) != nil else {
                throw CashuError.invalidHexString
            }
        }
    }
    
    /// Select optimal proofs for spending using a greedy algorithm
    private func selectOptimalProofs(from proofs: [Proof], targetAmount: Int) throws -> [Proof] {
        guard targetAmount > 0 else {
            throw CashuError.invalidAmount
        }
        
        // Sort proofs by amount (ascending) to prefer smaller denominations
        let sortedProofs = proofs.sorted { $0.amount < $1.amount }
        
        var selectedProofs: [Proof] = []
        var remainingAmount = targetAmount
        
        // First, try to find exact matches
        for proof in sortedProofs {
            if proof.amount == remainingAmount {
                selectedProofs.append(proof)
                return selectedProofs
            }
        }
        
        // If no exact match, use greedy selection
        for proof in sortedProofs {
            if proof.amount <= remainingAmount {
                selectedProofs.append(proof)
                remainingAmount -= proof.amount
                
                if remainingAmount == 0 {
                    break
                }
            }
        }
        
        // If we still need more, add the smallest proof that covers the remainder
        if remainingAmount > 0 {
            if let nextProof = sortedProofs.first(where: { proof in
                proof.amount >= remainingAmount && !selectedProofs.contains(where: { $0.secret == proof.secret })
            }) {
                selectedProofs.append(nextProof)
            } else {
                throw CashuError.balanceInsufficient
            }
        }
        
        return selectedProofs
    }
}

// MARK: - Proof Extensions

extension Proof {
    /// Check if this proof is valid (basic validation)
    public var isValidProof: Bool {
        return amount > 0 && 
               !secret.isEmpty && 
               !C.isEmpty && 
               !id.isEmpty &&
               Data(hexString: C) != nil
    }
    
    /// Get the proof's denomination (amount)
    public var denomination: Int {
        return amount
    }
    
    /// Check if proof belongs to a specific keyset
    public func belongsTo(keysetID: String) -> Bool {
        return id == keysetID
    }
}

// MARK: - Collection Extensions

extension Collection where Element == Proof {
    /// Calculate total value of proofs
    public var totalValue: Int {
        return reduce(0) { $0 + $1.amount }
    }
    
    /// Filter proofs by keyset ID
    public func proofs(for keysetID: String) -> [Proof] {
        return filter { $0.id == keysetID }
    }
    
    /// Group proofs by keyset ID
    public func groupedByKeyset() -> [String: [Proof]] {
        return Dictionary(grouping: self) { $0.id }
    }
    
    /// Get unique keyset IDs
    public var keysetIDs: Set<String> {
        return Set(map { $0.id })
    }
}