//
//  PerformanceBenchmarksSimple.swift
//  CashuKitTests
//
//  Simplified performance benchmarks for CashuKit operations
//

import Testing
@testable import CashuKit
import Foundation
@preconcurrency import P256K

@Suite("Performance Benchmarks")
struct PerformanceBenchmarksSimple {
    
    @Test("Simple cache performance")
    func testSimpleCachePerformance() async throws {
        let cache = SimpleCache<String, String>(maxSize: 10000)
        let iterations = 10000
        
        // Benchmark writes
        let writeStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<iterations {
            await cache.set("key\(i)", value: "value\(i)")
        }
        let writeTime = CFAbsoluteTimeGetCurrent() - writeStart
        
        print("Cache write: \(iterations) ops in \(String(format: "%.3f", writeTime))s")
        print("Average: \(String(format: "%.3f", writeTime / Double(iterations) * 1000))ms/op")
        
        // Benchmark reads
        let readStart = CFAbsoluteTimeGetCurrent()
        var hits = 0
        for i in 0..<iterations {
            if await cache.get("key\(i)") != nil {
                hits += 1
            }
        }
        let readTime = CFAbsoluteTimeGetCurrent() - readStart
        
        print("Cache read: \(iterations) ops in \(String(format: "%.3f", readTime))s")
        print("Hit rate: \(Double(hits) / Double(iterations) * 100)%")
        
        #expect(writeTime < 2.0)
        #expect(readTime < 1.0)
    }
    
    @Test("Proof storage performance")
    func testProofStoragePerformance() async throws {
        let storage = OptimizedProofStorage()
        
        // Create test proofs
        let proofs = (0..<1000).map { i in
            Proof(
                amount: [1, 2, 4, 8, 16, 32, 64][i % 7],
                id: "keyset\(i % 5)",
                secret: "secret\(i)",
                C: "C\(i)"
            )
        }
        
        // Benchmark insertion
        let insertStart = CFAbsoluteTimeGetCurrent()
        for proof in proofs {
            _ = await storage.store(proof)
        }
        let insertTime = CFAbsoluteTimeGetCurrent() - insertStart
        
        print("Proof insertion: \(proofs.count) proofs in \(String(format: "%.3f", insertTime))s")
        
        // Benchmark queries
        let queryStart = CFAbsoluteTimeGetCurrent()
        _ = await storage.getUnspentProofs()
        let queryTime = CFAbsoluteTimeGetCurrent() - queryStart
        
        print("Query unspent: \(String(format: "%.3f", queryTime * 1000))ms")
        
        // Benchmark selection
        let selectStart = CFAbsoluteTimeGetCurrent()
        _ = await storage.selectProofsForAmount(100)
        let selectTime = CFAbsoluteTimeGetCurrent() - selectStart
        
        print("Select for amount: \(String(format: "%.3f", selectTime * 1000))ms")
        
        #expect(insertTime < 1.0)
        #expect(queryTime < 0.01)
        #expect(selectTime < 0.01)
    }
    
    @Test("Batch processing performance")
    func testBatchProcessingPerformance() async throws {
        let items = Array(0..<100)
        
        // Sequential processing
        let seqStart = CFAbsoluteTimeGetCurrent()
        var seqResults: [Int] = []
        for item in items {
            // Simulate work
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            seqResults.append(item * 2)
        }
        let seqTime = CFAbsoluteTimeGetCurrent() - seqStart
        
        // Batch processing
        let batchStart = CFAbsoluteTimeGetCurrent()
        let batchResults = try await OptimizedCrypto.batchProcess(items: items) { item in
            // Simulate work
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return item * 2
        }
        let batchTime = CFAbsoluteTimeGetCurrent() - batchStart
        
        print("Sequential: \(String(format: "%.3f", seqTime))s")
        print("Batch: \(String(format: "%.3f", batchTime))s")
        print("Speedup: \(String(format: "%.1f", seqTime / batchTime))x")
        
        #expect(batchTime < seqTime)
        #expect(seqResults.count == batchResults.count)
    }
    
    @Test("Hash to curve caching")
    func testHashToCurveCaching() async throws {
        let testData = "test_data".data(using: .utf8)!
        
        // First call (cache miss)
        let firstStart = CFAbsoluteTimeGetCurrent()
        _ = try await OptimizedCrypto.cachedHashToCurve(testData)
        let firstTime = CFAbsoluteTimeGetCurrent() - firstStart
        
        // Second call (cache hit)
        let secondStart = CFAbsoluteTimeGetCurrent()
        _ = try await OptimizedCrypto.cachedHashToCurve(testData)
        let secondTime = CFAbsoluteTimeGetCurrent() - secondStart
        
        print("First call (miss): \(String(format: "%.3f", firstTime * 1000))ms")
        print("Second call (hit): \(String(format: "%.3f", secondTime * 1000))ms")
        print("Cache speedup: \(String(format: "%.1f", firstTime / secondTime))x")
        
        #expect(secondTime < firstTime)
    }
    
    @Test("Performance monitor")
    func testPerformanceMonitor() async throws {
        let monitor = PerformanceMonitor(operation: "Test Operation")
        
        // Simulate some work
        var sum = 0
        for i in 0..<1_000_000 {
            sum += i
        }
        
        monitor.end()
        
        #expect(sum > 0)
    }
    
    @Test("End-to-end optimization")
    func testEndToEndOptimization() async throws {
        let iterations = 100
        
        // Test with caching
        let cachedStart = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            // Cache mint info
            let mintInfo = MintInfo(
                name: "Test Mint",
                pubkey: "02test",
                version: "1.0",
                description: "Test",
                descriptionLong: nil,
                contact: nil,
                nuts: nil,
                motd: nil,
                iconURL: nil,
                urls: nil,
                time: Int(Date().timeIntervalSince1970),
                tosURL: nil
            )
            
            await PerformanceManager.shared.mintInfoCache.set("mint\(i % 10)", value: mintInfo)
            _ = await PerformanceManager.shared.mintInfoCache.get("mint\(i % 10)")
            
            // Store proof
            let proof = Proof(amount: i, id: "test", secret: "secret\(i)", C: "C\(i)")
            _ = await PerformanceManager.shared.proofStorage.store(proof)
        }
        
        let cachedTime = CFAbsoluteTimeGetCurrent() - cachedStart
        
        print("Cached operations: \(iterations) in \(String(format: "%.3f", cachedTime))s")
        print("Average: \(String(format: "%.3f", cachedTime / Double(iterations) * 1000))ms/op")
        
        #expect(cachedTime < 1.0)
    }
}