//
//  Game.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Game model used for the search UI and detail/log screens.
//  Maps from RAWG API responses and can be cached in Firestore.
//

import Foundation

/// Represents a video game in the Backlog'd app.
///
/// This is the app-level model used by views and view models.
/// Compatible with Firestore for caching game metadata.
struct Game: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let platforms: [String]
    let genres: [String]
    let description: String
    /// Cover art URL from RAWG API
    var coverURL: String?
    /// Release year, optional
    var releaseYear: Int?
    
    /// Convenience initializer
    init(
        id: Int,
        title: String,
        platforms: [String],
        genres: [String],
        description: String,
        coverURL: String? = nil,
        releaseYear: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.platforms = platforms
        self.genres = genres
        self.description = description
        self.coverURL = coverURL
        self.releaseYear = releaseYear
    }
}
