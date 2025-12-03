//
//  GameLogStore.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  View model for managing game logs.
//  Backed by Firestore via LogService for persistent storage.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class GameLogStore: ObservableObject {
    
    private let logService = LogService.shared
    private let authService = AuthService.shared
    
    /// All logs for the current user.
    @Published private(set) var logs: [GameLog] = []
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error message, if any
    @Published var errorMessage: String?
    
    /// Firestore listener registration
    private var listenerRegistration: ListenerRegistration?
    
    // MARK: - Init / Deinit
    
    init() {
        // Start observing logs when user is authenticated
        if let userID = authService.currentUserID {
            observeLogs(for: userID)
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    // MARK: - Public API
    
    /// Starts observing logs for a specific user (real-time updates).
    func observeLogs(for userID: String) {
        // Remove existing listener
        listenerRegistration?.remove()
        
        isLoading = true
        listenerRegistration = logService.observeLogs(for: userID) { [weak self] (result: Result<[GameLog], Error>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let logs):
                    self?.logs = logs
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = Self.userFriendlyErrorMessage(from: error)
                    print("Error fetching logs: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Stops observing logs (call when user signs out).
    func stopObserving() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        logs = []
    }
    
    /// Returns the log for a specific game, if it exists.
    func log(for gameId: Int) -> GameLog? {
        logs.first { $0.gameId == gameId }
    }
    
    /// Returns all logs that match a specific status
    /// (e.g. all `.completed` games).
    func logs(for status: GameStatus) -> [GameLog] {
        logs.filter { $0.status == status }
    }
    
    /// Creates or updates a log entry for the given game.
    ///
    /// - Parameters:
    ///   - game: The game being logged
    ///   - status: Current status
    ///   - rating: Optional rating (1-10)
    ///   - reviewText: Optional review text
    ///   - playtimeHours: Optional playtime in hours
    ///   - location: Optional location coordinates
    func upsertLog(
        for game: Game,
        status: GameStatus,
        rating: Int? = nil,
        reviewText: String? = nil,
        playtimeHours: Double? = nil,
        location: GeoPoint? = nil
    ) {
        upsertLogWithCompletion(
            for: game,
            status: status,
            rating: rating,
            reviewText: reviewText,
            playtimeHours: playtimeHours,
            location: location,
            completion: nil
        )
    }
    
    /// Creates or updates a log entry for the given game with a completion handler.
    ///
    /// - Parameters:
    ///   - game: The game being logged
    ///   - status: Current status
    ///   - rating: Optional rating (1-10)
    ///   - reviewText: Optional review text
    ///   - playtimeHours: Optional playtime in hours
    ///   - location: Optional location coordinates
    ///   - completion: Called with (success: Bool, errorMessage: String?) when save completes
    func upsertLogWithCompletion(
        for game: Game,
        status: GameStatus,
        rating: Int? = nil,
        reviewText: String? = nil,
        playtimeHours: Double? = nil,
        location: GeoPoint? = nil,
        completion: ((Bool, String?) -> Void)?
    ) {
        guard let userID = authService.currentUserID else {
            let errorMsg = "You must be signed in to log games. Please sign in and try again."
            errorMessage = errorMsg
            completion?(false, errorMsg)
            return
        }
        
        // Check if log already exists
        if let existingLog = log(for: game.id) {
            // Update existing log
            var updatedLog = existingLog
            updatedLog.status = status
            updatedLog.rating = rating
            updatedLog.reviewText = reviewText?.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedLog.playtimeHours = playtimeHours
            updatedLog.location = location
            updatedLog.updatedAt = Date()
            
            logService.upsertLog(updatedLog) { [weak self] (result: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Real-time listener will update logs automatically
                        completion?(true, nil)
                    case .failure(let error):
                        let errorMsg = Self.userFriendlyErrorMessage(from: error)
                        self?.errorMessage = errorMsg
                        completion?(false, errorMsg)
                    }
                }
            }
        } else {
            // Create new log
            let newLog = GameLog(
                id: UUID().uuidString,
                userID: userID,
                gameId: game.id,
                status: status,
                rating: rating,
                reviewText: reviewText?.trimmingCharacters(in: .whitespacesAndNewlines),
                playtimeHours: playtimeHours,
                createdAt: Date(),
                updatedAt: Date(),
                location: location
            )
            
            logService.upsertLog(newLog) { [weak self] (result: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Real-time listener will update logs automatically
                        completion?(true, nil)
                    case .failure(let error):
                        let errorMsg = Self.userFriendlyErrorMessage(from: error)
                        self?.errorMessage = errorMsg
                        completion?(false, errorMsg)
                    }
                }
            }
        }
    }
    
    /// Deletes a log entry.
    ///
    /// - Parameter log: The log entry to delete
    func deleteLog(_ log: GameLog) {
        logService.deleteLog(logID: log.id) { [weak self] (result: Result<Void, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Real-time listener will update logs automatically
                    break
                case .failure(let error):
                    self?.errorMessage = Self.userFriendlyErrorMessage(from: error)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    /// Converts Firestore errors to user-friendly messages.
    private static func userFriendlyErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        let errorMessage = nsError.localizedDescription.lowercased()
        
        // Network-related errors
        if errorMessage.contains("network") || errorMessage.contains("internet") || errorMessage.contains("offline") {
            return "Network error. Please check your connection and try again."
        }
        
        // Permission errors
        if errorMessage.contains("permission") || errorMessage.contains("unauthorized") {
            return "You don't have permission to perform this action. Please sign in and try again."
        }
        
        // Firestore-specific errors
        if errorMessage.contains("unavailable") {
            return "Service is temporarily unavailable. Please try again later."
        }
        
        // Generic fallback
        return "Something went wrong. Please try again."
    }
}


