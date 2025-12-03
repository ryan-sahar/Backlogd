//
//  GameService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Service responsible for fetching game data from the RAWG API.
//

import Foundation

/// Errors that can occur while talking to the RAWG API.
enum GameServiceError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build a valid search URL."
        case .requestFailed:
            return "The game server did not respond correctly."
        case .decodingFailed:
            return "Could not read the game data from the server."
        case .apiKeyMissing:
            return "RAWG API key is missing. Please configure it in APIKeys.swift."
        }
    }
}

/// Network-layer model that matches the RAWG /games search response.
private struct RawgGame: Decodable {
    let id: Int
    let name: String
    let platforms: [RawgPlatformWrapper]?
    let genres: [RawgNamedItem]?
    let background_image: String?
    let description: String?
    let released: String? // Release date as "YYYY-MM-DD"
}

private struct RawgPlatformWrapper: Decodable {
    let platform: RawgNamedItem
}

private struct RawgNamedItem: Decodable {
    let name: String
}

/// Top-level RAWG search response.
/// This struct decodes in a nonisolated context (URLSession completion handler runs on background queue).
/// The Swift 6 warning about main actor isolation is safe to ignore here as decoding happens off the main thread.
private nonisolated(unsafe) struct RawgSearchResponse: Decodable {
    let results: [RawgGame]
}

/// Service object for searching games.
struct GameService {
    
    /// Shared instance (simple singleton).
    static let shared = GameService()
    
    /// Base URL for RAWG API.
    private let baseURL = URL(string: "https://api.rawg.io/api")!
    
    /// Searches for games using the RAWG API.
    ///
    /// - Parameters:
    ///   - query: Search text (game name, etc.)
    ///   - completion: Called on the main thread with either `[Game]` or an error.
    func searchGames(query: String, completion: @escaping (Result<[Game], GameServiceError>) -> Void) {
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success([]))
            return
        }
        
        // Ensure an API key is configured.
        guard !APIKeys.rawg.isEmpty, APIKeys.rawg != "YOUR_RAWG_API_KEY_HERE" else {
            completion(.failure(.apiKeyMissing))
            return
        }
        
        // Build URL: /games?key=API_KEY&search=...
        var components = URLComponents(url: baseURL.appendingPathComponent("games"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "key", value: APIKeys.rawg),
            URLQueryItem(name: "search", value: trimmed),
            URLQueryItem(name: "page_size", value: "20")
        ]
        
        guard let url = components?.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            
            // Network error or missing data
            if let _ = error {
                DispatchQueue.main.async {
                    completion(.failure(.requestFailed))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.requestFailed))
                }
                return
            }
            
            do {
                // Decode in background thread (already nonisolated context)
                // Use nonisolated(unsafe) to decode without main actor isolation
                let decoder = JSONDecoder()
                let decoded: RawgSearchResponse = try decoder.decode(RawgSearchResponse.self, from: data)
                
                // Map RawgGame → Game (our app model)
                let mapped: [Game] = decoded.results.map { rawgGame in
                    // Extract release year from "YYYY-MM-DD" format
                    let releaseYear: Int? = {
                        guard let released = rawgGame.released,
                              released.count >= 4 else {
                            return nil
                        }
                        return Int(String(released.prefix(4)))
                    }()
                    
                    return Game(
                        id: rawgGame.id,
                        title: rawgGame.name,
                        platforms: rawgGame.platforms?.map { $0.platform.name } ?? [],
                        genres: rawgGame.genres?.map { $0.name } ?? [],
                        description: rawgGame.description ?? "No description available.",
                        coverURL: rawgGame.background_image,
                        releaseYear: releaseYear
                    )
                }
                
                DispatchQueue.main.async {
                    completion(.success(mapped))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.decodingFailed))
                }
            }
        }
        
        task.resume()
    }
}
