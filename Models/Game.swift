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
    
    /// Sample data used for local search and previews.
    static let mockGames: [Game] = [
        Game(
            id: 1,
            title: "Elden Ring",
            platforms: ["PS5", "Xbox Series X|S", "PC"],
            genres: ["Action RPG", "Open World"],
            description: "A dark fantasy open-world action RPG from FromSoftware, featuring challenging combat, exploration, and deep lore.",
            releaseYear: 2022
        ),
        Game(
            id: 2,
            title: "The Legend of Zelda: Tears of the Kingdom",
            platforms: ["Nintendo Switch"],
            genres: ["Action Adventure"],
            description: "Link returns to Hyrule in a sprawling adventure that spans both the surface and the skies, with new abilities and sandbox systems.",
            releaseYear: 2023
        ),
        Game(
            id: 3,
            title: "Hades",
            platforms: ["Switch", "PC", "PS5", "Xbox"],
            genres: ["Roguelike", "Action"],
            description: "Battle out of the Underworld in this fast-paced roguelike, combining tight combat with strong storytelling and voice acting.",
            releaseYear: 2020
        ),
        Game(
            id: 4,
            title: "Baldur's Gate 3",
            platforms: ["PC", "PS5", "Xbox Series X|S"],
            genres: ["RPG"],
            description: "A cinematic, choice-driven RPG set in the Dungeons & Dragons universe, with turn-based combat and deep character customization.",
            releaseYear: 2023
        ),
        Game(
            id: 5,
            title: "Stardew Valley",
            platforms: ["Switch", "PC", "PS4", "Xbox"],
            genres: ["Farming", "Simulation"],
            description: "A cozy farming sim where you restore a rundown farm, befriend villagers, fish, mine, and relax at your own pace.",
            releaseYear: 2016
        )
    ]
}
