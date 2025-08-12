//
//  BackgroundTaskManager.swift
//  CashuKit
//
//  Manages background operations and app lifecycle transitions
//

import Foundation
import BackgroundTasks
import CoreCashu
import Combine

/// Manages background tasks and operations that continue when app is suspended
public actor BackgroundTaskManager {
    
    // MARK: - Types
    
    public enum TaskType: String, CaseIterable {
        case balanceRefresh = "com.cashukit.balance.refresh"
        case proofValidation = "com.cashukit.proof.validation"
        case tokenSync = "com.cashukit.token.sync"
        case mintHealthCheck = "com.cashukit.mint.health"
        
        var identifier: String { rawValue }
        
        var minimumInterval: TimeInterval {
            switch self {
            case .balanceRefresh: return 15 * 60 // 15 minutes
            case .proofValidation: return 60 * 60 // 1 hour
            case .tokenSync: return 30 * 60 // 30 minutes
            case .mintHealthCheck: return 2 * 60 * 60 // 2 hours
            }
        }
    }
    
    public struct PendingOperation: Codable, Identifiable, Sendable {
        public let id = UUID()
        public let type: String
        public let data: Data
        public let createdAt: Date
        public var isExecuting: Bool = false
        public var completedAt: Date?
        public var error: String?
        
        public enum CodingKeys: String, CodingKey {
            case type, data, createdAt, isExecuting, completedAt, error
        }
    }
    
    public enum BackgroundError: LocalizedError {
        case taskNotRegistered
        case taskExpired
        case insufficientTime
        case networkUnavailable
        case operationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .taskNotRegistered:
                return "Background task not registered in Info.plist"
            case .taskExpired:
                return "Background task expired before completion"
            case .insufficientTime:
                return "Insufficient time to complete operation"
            case .networkUnavailable:
                return "Network unavailable for background operation"
            case .operationFailed(let reason):
                return "Operation failed: \(reason)"
            }
        }
    }
    
    // MARK: - Properties
    
    private var registeredTasks: Set<TaskType> = []
    private var pendingOperations: [PendingOperation] = []
    private var activeURLSession: URLSession?
    private let logger: OSLogLogger
    private let urlSessionDelegate: URLSessionDelegateHandler
    private let networkMonitor: NetworkMonitor
    var backgroundCompletionHandlers: [String: @Sendable () -> Void] = [:]
    
    // Background URL Session
    private lazy var backgroundURLSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.cashukit.background")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.allowsCellularAccess = UserDefaults.standard.bool(forKey: "AllowCellularData")
        
        return URLSession(configuration: config, delegate: urlSessionDelegate, delegateQueue: nil)
    }()
    
    // MARK: - Initialization
    
    public init(networkMonitor: NetworkMonitor) {
        self.logger = OSLogLogger(category: "BackgroundTasks", minimumLevel: .info)
        self.networkMonitor = networkMonitor
        self.urlSessionDelegate = URLSessionDelegateHandler(backgroundTaskManager: nil)
        self.urlSessionDelegate.backgroundTaskManager = self
        Task {
            await loadPendingOperations()
        }
    }
    
    // MARK: - Public Methods
    
    /// Clear a completion handler
    public func clearCompletionHandler(for identifier: String) {
        backgroundCompletionHandlers[identifier] = nil
    }
    
    /// Register background tasks with the system
    public func registerBackgroundTasks() {
        #if os(iOS) || os(tvOS)
        for taskType in TaskType.allCases {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: taskType.identifier,
                using: nil
            ) { [weak self] task in
                Task {
                    await self?.handleBackgroundTask(task, type: taskType)
                }
            }
            registeredTasks.insert(taskType)
            logger.info("Registered background task: \(taskType.identifier)")
        }
        #endif
    }
    
    /// Schedule a background task
    public func scheduleBackgroundTask(
        _ type: TaskType,
        earliestBeginDate: Date? = nil
    ) throws {
        #if os(iOS) || os(tvOS)
        guard registeredTasks.contains(type) else {
            throw BackgroundError.taskNotRegistered
        }
        
        let request = BGAppRefreshTaskRequest(identifier: type.identifier)
        request.earliestBeginDate = earliestBeginDate ?? Date(timeIntervalSinceNow: type.minimumInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled background task: \(type.identifier)")
        } catch {
            logger.error("Failed to schedule background task: \(error.localizedDescription)")
            throw error
        }
        #endif
    }
    
    /// Schedule all background tasks
    public func scheduleAllBackgroundTasks() {
        for taskType in TaskType.allCases {
            try? scheduleBackgroundTask(taskType)
        }
    }
    
    /// Cancel a scheduled background task
    public func cancelBackgroundTask(_ type: TaskType) {
        #if os(iOS) || os(tvOS)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: type.identifier)
        logger.info("Cancelled background task: \(type.identifier)")
        #endif
    }
    
    /// Add an operation to be executed in the background
    public func addPendingOperation(
        type: String,
        data: Data
    ) {
        let operation = PendingOperation(
            type: type,
            data: data,
            createdAt: Date()
        )
        
        pendingOperations.append(operation)
        savePendingOperations()
        
        logger.info("Added pending operation: \(type)")
        
        // Try to execute immediately if possible
        Task {
            await executePendingOperations()
        }
    }
    
    /// Execute pending operations
    public func executePendingOperations() async {
        let operations = pendingOperations.filter { !$0.isExecuting && $0.completedAt == nil }
        
        for operation in operations {
            // Mark as executing
            if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                pendingOperations[index].isExecuting = true
            }
            
            do {
                try await executeOperation(operation)
                
                // Mark as completed
                if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                    pendingOperations[index].isExecuting = false
                    pendingOperations[index].completedAt = Date()
                }
                
                logger.info("Completed pending operation: \(operation.type)")
            } catch {
                // Mark as failed
                if let index = pendingOperations.firstIndex(where: { $0.id == operation.id }) {
                    pendingOperations[index].isExecuting = false
                    pendingOperations[index].error = error.localizedDescription
                }
                
                logger.error("Failed to execute operation \(operation.type): \(error.localizedDescription)")
            }
        }
        
        // Clean up old completed operations (older than 24 hours)
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        pendingOperations.removeAll { operation in
            if let completedAt = operation.completedAt {
                return completedAt < cutoffDate
            }
            return false
        }
        
        savePendingOperations()
    }
    
    /// Start a background URL session download
    public func startBackgroundDownload(
        from url: URL,
        completion: @escaping (Result<Data, any Error>) -> Void
    ) -> URLSessionDownloadTask {
        let task = backgroundURLSession.downloadTask(with: url)
        
        // Store completion handler
        urlSessionDelegate.setCompletionHandler(
            for: task.taskIdentifier,
            handler: completion
        )
        
        task.resume()
        logger.info("Started background download from: \(url.absoluteString)")
        
        return task
    }
    
    /// Handle app entering background
    public func handleEnterBackground() {
        logger.info("App entering background")
        
        // Save current state
        savePendingOperations()
        
        // Schedule background tasks
        scheduleAllBackgroundTasks()
        
        // Start any critical pending operations
        Task {
            await executeCriticalOperations()
        }
    }
    
    /// Handle app entering foreground
    public func handleEnterForeground() {
        logger.info("App entering foreground")
        
        // Cancel scheduled tasks as we're active now
        for taskType in TaskType.allCases {
            cancelBackgroundTask(taskType)
        }
        
        // Execute any pending operations
        Task {
            await executePendingOperations()
        }
    }
    
    /// Handle app termination
    public func handleTermination() {
        logger.info("App terminating")
        
        // Save all state
        savePendingOperations()
        
        // Schedule critical tasks for next launch
        try? scheduleBackgroundTask(.balanceRefresh, earliestBeginDate: Date(timeIntervalSinceNow: 60))
    }
    
    // MARK: - Private Methods
    
    #if os(iOS) || os(tvOS)
    private func handleBackgroundTask(_ task: BGTask, type: TaskType) async {
        logger.info("Handling background task: \(type.identifier)")
        
        // Set up expiration handler
        task.expirationHandler = { [weak self] in
            self?.logger.warning("Background task expired: \(type.identifier)")
            task.setTaskCompleted(success: false)
        }
        
        do {
            switch type {
            case .balanceRefresh:
                try await performBalanceRefresh()
            case .proofValidation:
                try await performProofValidation()
            case .tokenSync:
                try await performTokenSync()
            case .mintHealthCheck:
                try await performMintHealthCheck()
            }
            
            task.setTaskCompleted(success: true)
            
            // Schedule next execution
            try? scheduleBackgroundTask(type)
            
        } catch {
            logger.error("Background task failed: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }
    }
    #endif
    
    private func executeOperation(_ operation: PendingOperation) async throws {
        // Implementation would decode operation data and execute
        // This is a placeholder for actual implementation
        logger.info("Executing operation: \(operation.type)")
        
        // Check network availability
        guard await networkMonitor.isConnected else {
            throw BackgroundError.networkUnavailable
        }
        
        // Execute based on operation type
        // This would be customized based on your actual operations
    }
    
    private func executeCriticalOperations() async {
        let criticalOps = pendingOperations.filter { operation in
            // Define what makes an operation critical
            operation.type.contains("send") || operation.type.contains("receive")
        }
        
        for operation in criticalOps {
            do {
                try await executeOperation(operation)
            } catch {
                logger.error("Critical operation failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Background Task Implementations
    
    private func performBalanceRefresh() async throws {
        logger.info("Performing balance refresh")
        // Implementation would refresh wallet balance
        // This is a placeholder
    }
    
    private func performProofValidation() async throws {
        logger.info("Performing proof validation")
        // Implementation would validate stored proofs
        // This is a placeholder
    }
    
    private func performTokenSync() async throws {
        logger.info("Performing token sync")
        // Implementation would sync tokens with mint
        // This is a placeholder
    }
    
    private func performMintHealthCheck() async throws {
        logger.info("Performing mint health check")
        // Implementation would check mint availability
        // This is a placeholder
    }
    
    // MARK: - Persistence
    
    private func savePendingOperations() {
        guard let data = try? JSONEncoder().encode(pendingOperations) else { return }
        UserDefaults.standard.set(data, forKey: "PendingOperations")
    }
    
    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: "PendingOperations"),
              let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) else {
            return
        }
        
        pendingOperations = operations
        logger.info("Loaded \(operations.count) pending operations")
    }
}

// MARK: - URLSession Delegate Handler

final class URLSessionDelegateHandler: NSObject, URLSessionDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    
    weak var backgroundTaskManager: BackgroundTaskManager?
    
    private var completionHandlers: [Int: (Result<Data, any Error>) -> Void] = [:]
    private let logger = OSLogLogger(category: "URLSessionDelegate", minimumLevel: .info)
    
    init(backgroundTaskManager: BackgroundTaskManager?) {
        self.backgroundTaskManager = backgroundTaskManager
        super.init()
    }
    
    func setCompletionHandler(for taskIdentifier: Int, handler: @escaping (Result<Data, any Error>) -> Void) {
        completionHandlers[taskIdentifier] = handler
    }
    
    // MARK: - URLSessionDelegate
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.info("URLSession finished events for background session")
        
        // Call stored completion handler if app was relaunched
        Task { [weak self] in
            if let sessionIdentifier = session.configuration.identifier,
               let manager = self?.backgroundTaskManager,
               let completionHandler = await manager.backgroundCompletionHandlers[sessionIdentifier] {
                completionHandler()
                await manager.clearCompletionHandler(for: sessionIdentifier)
            }
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        logger.info("Download finished to: \(location.path)")
        
        do {
            let data = try Data(contentsOf: location)
            
            if let handler = completionHandlers[downloadTask.taskIdentifier] {
                handler(.success(data))
                completionHandlers[downloadTask.taskIdentifier] = nil
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: location)
            
        } catch {
            if let handler = completionHandlers[downloadTask.taskIdentifier] {
                handler(.failure(error))
                completionHandlers[downloadTask.taskIdentifier] = nil
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error = error {
            logger.error("Task completed with error: \(error.localizedDescription)")
            
            if let handler = completionHandlers[task.taskIdentifier] {
                handler(.failure(error))
                completionHandlers[task.taskIdentifier] = nil
            }
        }
    }
}

// MARK: - App Lifecycle Integration

#if os(iOS) || os(tvOS)
import UIKit

public extension BackgroundTaskManager {
    
    /// Set up app lifecycle observers
    func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.handleEnterBackground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.handleEnterForeground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.handleTermination()
            }
        }
        
        logger.info("Set up lifecycle observers")
    }
    
    /// Store completion handler for background URL session
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        backgroundCompletionHandlers[identifier] = completionHandler
        logger.info("Stored completion handler for session: \(identifier)")
    }
    
    func clearCompletionHandler(for identifier: String) {
        backgroundCompletionHandlers[identifier] = nil
    }
}
#endif

// MARK: - Testing Support

#if DEBUG
public extension BackgroundTaskManager {
    
    /// Simulate background task execution for testing
    func simulateBackgroundTask(_ type: TaskType) async throws {
        logger.info("Simulating background task: \(type.identifier)")
        
        switch type {
        case .balanceRefresh:
            try await performBalanceRefresh()
        case .proofValidation:
            try await performProofValidation()
        case .tokenSync:
            try await performTokenSync()
        case .mintHealthCheck:
            try await performMintHealthCheck()
        }
    }
    
    /// Get pending operations for testing
    var testPendingOperations: [PendingOperation] {
        pendingOperations
    }
}
#endif
