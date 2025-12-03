//
//  LogService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Service layer for game log operations in Firestore.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service responsible for game log CRUD operations in Firestore.
final class LogService {
    
    static let shared = LogService()
    
    private let db = Firestore.firestore()
    private let logsCollection = "logs"
    
    private init() {}
    
    /// Creates or updates a log entry for a game.
    ///
    /// - Parameters:
    ///   - log: The log entry to save
    ///   - completion: Called with result (success or error)
    func upsertLog(_ log: GameLog, completion: @escaping (Result<Void, Error>) -> Void) {
        let logRef = db.collection(logsCollection).document(log.id)
        
        var logData = log.toDictionary()
        logData["updatedAt"] = Timestamp(date: Date())
        
        logRef.setData(logData, merge: true) { error in
            if let error = error {
                print("❌ LogService: Failed to save log - \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Error code: \(nsError.code)")
                    print("   Error domain: \(nsError.domain)")
                    print("   User info: \(nsError.userInfo)")
                }
                completion(.failure(error))
            } else {
                print("✅ LogService: Successfully saved log with ID: \(log.id)")
                completion(.success(()))
            }
        }
    }
    
    /// Fetches all logs for a specific user.
    ///
    /// - Parameters:
    ///   - userID: Firebase Auth UID
    ///   - completion: Called with result ([GameLog] or error)
    func fetchLogs(for userID: String, completion: @escaping (Result<[GameLog], Error>) -> Void) {
        db.collection(logsCollection)
            .whereField("userID", isEqualTo: userID)
            .order(by: "updatedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let logs = documents.compactMap { doc -> GameLog? in
                    let data = doc.data()
                    return GameLog(from: data, id: doc.documentID)
                }
                
                completion(.success(logs))
            }
    }
    
    /// Fetches logs for a specific user with real-time updates.
    ///
    /// - Parameters:
    ///   - userID: Firebase Auth UID
    ///   - onUpdate: Called whenever logs change
    /// - Returns: A listener registration that can be removed
    func observeLogs(for userID: String, onUpdate: @escaping (Result<[GameLog], Error>) -> Void) -> ListenerRegistration {
        return db.collection(logsCollection)
            .whereField("userID", isEqualTo: userID)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onUpdate(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    onUpdate(.success([]))
                    return
                }
                
                let logs = documents.compactMap { doc -> GameLog? in
                    let data = doc.data()
                    return GameLog(from: data, id: doc.documentID)
                }
                
                onUpdate(.success(logs))
            }
    }
    
    /// Fetches a specific log entry for a game and user.
    ///
    /// - Parameters:
    ///   - gameID: RAWG game ID
    ///   - userID: Firebase Auth UID
    ///   - completion: Called with result (GameLog? or error)
    func fetchLog(gameID: Int, userID: String, completion: @escaping (Result<GameLog?, Error>) -> Void) {
        db.collection(logsCollection)
            .whereField("gameId", isEqualTo: gameID)
            .whereField("userID", isEqualTo: userID)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(.success(nil))
                    return
                }
                
                let data = document.data()
                if let log = GameLog(from: data, id: document.documentID) {
                    completion(.success(log))
                } else {
                    completion(.success(nil))
                }
            }
    }
    
    /// Deletes a log entry.
    ///
    /// - Parameters:
    ///   - logID: Log document ID
    ///   - completion: Called with result (success or error)
    func deleteLog(logID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(logsCollection).document(logID).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetches logs for multiple users (for feed functionality).
    ///
    /// - Parameters:
    ///   - userIDs: Array of Firebase Auth UIDs
    ///   - limit: Maximum number of logs to return
    ///   - completion: Called with result ([GameLog] or error)
    func fetchLogs(for userIDs: [String], limit: Int = 50, completion: @escaping (Result<[GameLog], Error>) -> Void) {
        // Firestore 'in' queries are limited to 10 items, so we need to batch if needed
        guard !userIDs.isEmpty else {
            completion(.success([]))
            return
        }
        
        let batches = userIDs.chunked(into: 10)
        var allLogs: [GameLog] = []
        let group = DispatchGroup()
        var lastError: Error?
        
        for batch in batches {
            group.enter()
            db.collection(logsCollection)
                .whereField("userID", in: batch)
                .order(by: "updatedAt", descending: true)
                .limit(to: limit)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        lastError = error
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let logs = documents.compactMap { doc -> GameLog? in
                        let data = doc.data()
                        return GameLog(from: data, id: doc.documentID)
                    }
                    
                    allLogs.append(contentsOf: logs)
                }
        }
        
        group.notify(queue: .main) {
            if let error = lastError {
                completion(.failure(error))
            } else {
                // Sort by updatedAt descending and limit
                allLogs.sort { $0.updatedAt > $1.updatedAt }
                let limited = Array(allLogs.prefix(limit))
                completion(.success(limited))
            }
        }
    }
}

// MARK: - Helper Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

