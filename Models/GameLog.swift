//
//  GameLog.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Models representing user log entries for games.
//  Compatible with Firestore for persistent storage.
//

import Foundation
import FirebaseFirestore

/// High-level status for a game in the user's backlog.
///
/// This keeps the wording consistent across the app.
enum GameStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted = "Not Started"
    case playing = "Playing"
    case completed = "Completed"
    case shelved = "Shelved"
    case wishlist = "Wishlist"
    
    var id: String { rawValue }
}

/// Represents a user's log entry for a particular game.
/// 
/// This is the Firestore-compatible model. The `id` is a Firestore document ID (String),
/// and dates are stored as Timestamps in Firestore.
struct GameLog: Identifiable, Codable, Hashable {
    /// Firestore document ID
    var id: String
    /// Firebase Auth user ID
    var userID: String
    /// RAWG game ID
    var gameId: Int
    /// Game title (stored for display without needing to fetch from API)
    var gameTitle: String?
    /// Game cover URL (stored for display without needing to fetch from API)
    var gameCoverURL: String?
    /// Game description (stored for display without needing to fetch from API)
    var gameDescription: String?
    /// Game platforms (stored for display without needing to fetch from API)
    var gamePlatforms: [String]?
    /// Game genres (stored for display without needing to fetch from API)
    var gameGenres: [String]?
    /// Game release year (stored for display without needing to fetch from API)
    var gameReleaseYear: Int?
    
    var status: GameStatus
    /// Rating from 1-10, optional
    var rating: Int?
    /// Review text, optional
    var reviewText: String?
    /// Playtime in hours, optional
    var playtimeHours: Double?
    
    var createdAt: Date
    var updatedAt: Date
    
    /// Location coordinates (optional) for map features
    var location: GeoPoint?
    
    /// Convenience initializer for creating new logs
    init(
        id: String = UUID().uuidString,
        userID: String,
        gameId: Int,
        status: GameStatus,
        rating: Int? = nil,
        reviewText: String? = nil,
        playtimeHours: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        location: GeoPoint? = nil,
        gameTitle: String? = nil,
        gameCoverURL: String? = nil,
        gameDescription: String? = nil,
        gamePlatforms: [String]? = nil,
        gameGenres: [String]? = nil,
        gameReleaseYear: Int? = nil
    ) {
        self.id = id
        self.userID = userID
        self.gameId = gameId
        self.status = status
        self.rating = rating
        self.reviewText = reviewText
        self.playtimeHours = playtimeHours
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.location = location
        self.gameTitle = gameTitle
        self.gameCoverURL = gameCoverURL
        self.gameDescription = gameDescription
        self.gamePlatforms = gamePlatforms
        self.gameGenres = gameGenres
        self.gameReleaseYear = gameReleaseYear
    }
}

// MARK: - Firestore Codable Support

extension GameLog {
    /// Initialize from Firestore document
    init?(from dictionary: [String: Any], id: String) {
        guard let userID = dictionary["userID"] as? String,
              let gameId = dictionary["gameId"] as? Int,
              let statusString = dictionary["status"] as? String,
              let status = GameStatus(rawValue: statusString) else {
            return nil
        }
        
        self.id = id
        self.userID = userID
        self.gameId = gameId
        self.status = status
        self.rating = dictionary["rating"] as? Int
        self.reviewText = dictionary["reviewText"] as? String
        self.playtimeHours = dictionary["playtimeHours"] as? Double
        self.gameTitle = dictionary["gameTitle"] as? String
        self.gameCoverURL = dictionary["gameCoverURL"] as? String
        self.gameDescription = dictionary["gameDescription"] as? String
        self.gamePlatforms = dictionary["gamePlatforms"] as? [String]
        self.gameGenres = dictionary["gameGenres"] as? [String]
        self.gameReleaseYear = dictionary["gameReleaseYear"] as? Int
        
        // Handle Firestore Timestamps
        if let createdAtTimestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let updatedAtTimestamp = dictionary["updatedAt"] as? Timestamp {
            self.updatedAt = updatedAtTimestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
        
        self.location = dictionary["location"] as? GeoPoint
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userID": userID,
            "gameId": gameId,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        
        if let rating = rating {
            dict["rating"] = rating
        }
        if let reviewText = reviewText {
            dict["reviewText"] = reviewText
        }
        if let playtimeHours = playtimeHours {
            dict["playtimeHours"] = playtimeHours
        }
        if let location = location {
            dict["location"] = location
        }
        if let gameTitle = gameTitle {
            dict["gameTitle"] = gameTitle
        }
        if let gameCoverURL = gameCoverURL {
            dict["gameCoverURL"] = gameCoverURL
        }
        if let gameDescription = gameDescription {
            dict["gameDescription"] = gameDescription
        }
        if let gamePlatforms = gamePlatforms {
            dict["gamePlatforms"] = gamePlatforms
        }
        if let gameGenres = gameGenres {
            dict["gameGenres"] = gameGenres
        }
        if let gameReleaseYear = gameReleaseYear {
            dict["gameReleaseYear"] = gameReleaseYear
        }
        
        return dict
    }
    
    /// Creates a Game object from the stored game metadata in this log.
    /// Falls back to placeholder data if metadata is missing.
    func toGame() -> Game {
        return Game(
            id: gameId,
            title: gameTitle ?? "Game \(gameId)",
            platforms: gamePlatforms ?? [],
            genres: gameGenres ?? [],
            description: gameDescription ?? "No description available.",
            coverURL: gameCoverURL,
            releaseYear: gameReleaseYear
        )
    }
}
