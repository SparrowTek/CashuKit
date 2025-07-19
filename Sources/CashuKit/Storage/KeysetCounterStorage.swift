//
//  KeysetCounterStorage.swift
//  CashuKit
//
//  Persistence for keyset counters used in NUT-13 deterministic key derivation
//

import Foundation

// MARK: - Storage Protocol

@MainActor
public protocol KeysetCounterStorage: Sendable {
    func getCounter(for keysetID: String) async throws -> UInt32?
    func setCounter(for keysetID: String, value: UInt32) async throws
    func getAllCounters() async throws -> [String: UInt32]
    func deleteCounter(for keysetID: String) async throws
    func deleteAllCounters() async throws
}

// MARK: - In-Memory Storage

public final class InMemoryKeysetCounterStorage: KeysetCounterStorage, Sendable {
    private var counters: [String: UInt32] = [:]
    
    public nonisolated init() {}
    
    public func getCounter(for keysetID: String) async throws -> UInt32? {
        return counters[keysetID]
    }
    
    public func setCounter(for keysetID: String, value: UInt32) async throws {
        counters[keysetID] = value
    }
    
    public func getAllCounters() async throws -> [String: UInt32] {
        return counters
    }
    
    public func deleteCounter(for keysetID: String) async throws {
        counters.removeValue(forKey: keysetID)
    }
    
    public func deleteAllCounters() async throws {
        counters.removeAll()
    }
}

// MARK: - UserDefaults Storage

@MainActor
public final class UserDefaultsKeysetCounterStorage: KeysetCounterStorage, Sendable {
    private let suiteName: String?
    private let keyPrefix = "cashu_keyset_counter_"
    private let userDefaults: UserDefaults
    
    public init(suiteName: String? = nil) throws {
        if let suiteName = suiteName {
            guard let userDefaults = UserDefaults(suiteName: suiteName) else {
                throw CashuError.storageError("Failed to create UserDefaults with suite: \(suiteName)")
            }
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults.standard
        }
        self.suiteName = suiteName
    }
    
    public func getCounter(for keysetID: String) async throws -> UInt32? {
        let key = keyPrefix + keysetID
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }
        let value = userDefaults.integer(forKey: key)
        return UInt32(value)
    }
    
    public func setCounter(for keysetID: String, value: UInt32) async throws {
        let key = keyPrefix + keysetID
        userDefaults.set(Int(value), forKey: key)
    }
    
    public func getAllCounters() async throws -> [String: UInt32] {
        var counters: [String: UInt32] = [:]
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(keyPrefix) {
                let keysetID = String(key.dropFirst(keyPrefix.count))
                if let value = try await getCounter(for: keysetID) {
                    counters[keysetID] = value
                }
            }
        }
        
        return counters
    }
    
    public func deleteCounter(for keysetID: String) async throws {
        let key = keyPrefix + keysetID
        userDefaults.removeObject(forKey: key)
    }
    
    public func deleteAllCounters() async throws {
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(keyPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - File-Based Storage

@MainActor
public final class FileKeysetCounterStorage: KeysetCounterStorage, Sendable {
    private let fileURL: URL
    private let fileManager = FileManager.default
    
    public init(directoryURL: URL? = nil, filename: String = "keyset_counters.json") throws {
        let directory = directoryURL ?? FileKeysetCounterStorage.defaultDirectory()
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        self.fileURL = directory.appendingPathComponent(filename)
    }
    
    private static func defaultDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first 
            ?? FileManager.default.temporaryDirectory
        return documentsPath.appendingPathComponent("CashuKit", isDirectory: true)
    }
    
    public func getCounter(for keysetID: String) async throws -> UInt32? {
        let counters = try await loadCounters()
        return counters[keysetID]
    }
    
    public func setCounter(for keysetID: String, value: UInt32) async throws {
        var counters = try await loadCounters()
        counters[keysetID] = value
        try await saveCounters(counters)
    }
    
    public func getAllCounters() async throws -> [String: UInt32] {
        return try await loadCounters()
    }
    
    public func deleteCounter(for keysetID: String) async throws {
        var counters = try await loadCounters()
        counters.removeValue(forKey: keysetID)
        try await saveCounters(counters)
    }
    
    public func deleteAllCounters() async throws {
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    private func loadCounters() async throws -> [String: UInt32] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([String: UInt32].self, from: data)
    }
    
    private func saveCounters(_ counters: [String: UInt32]) async throws {
        let data = try JSONEncoder().encode(counters)
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Enhanced Counter Manager with Persistence

public actor PersistentKeysetCounterManager {
    private let storage: any KeysetCounterStorage
    private var cache: [String: UInt32] = [:]
    private var isDirty = false
    
    public init(storage: any KeysetCounterStorage) {
        self.storage = storage
    }
    
    /// Load counters from storage
    public func loadFromStorage() async throws {
        cache = try await storage.getAllCounters()
        isDirty = false
    }
    
    /// Save counters to storage
    public func saveToStorage() async throws {
        guard isDirty else { return }
        
        for (keysetID, value) in cache {
            try await storage.setCounter(for: keysetID, value: value)
        }
        
        isDirty = false
    }
    
    /// Get counter for keyset
    public func getCounter(for keysetID: String) -> UInt32 {
        return cache[keysetID] ?? 0
    }
    
    /// Increment counter for keyset
    public func incrementCounter(for keysetID: String) {
        cache[keysetID] = (cache[keysetID] ?? 0) + 1
        isDirty = true
    }
    
    /// Set counter for keyset
    public func setCounter(for keysetID: String, value: UInt32) {
        cache[keysetID] = value
        isDirty = true
    }
    
    /// Reset counter for keyset
    public func resetCounter(for keysetID: String) {
        cache[keysetID] = 0
        isDirty = true
    }
    
    /// Get all counters
    public func getAllCounters() -> [String: UInt32] {
        return cache
    }
    
    /// Auto-save if dirty
    public func autoSaveIfNeeded() async throws {
        if isDirty {
            try await saveToStorage()
        }
    }
}