//
//  SearchViewModel.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  View model for the Search screen.
//  Uses RAWG API via GameService to search for games.
//

import Foundation
import Combine

final class SearchViewModel: ObservableObject {
    
    private let gameService = GameService.shared
    
    /// The text the user types in the search bar.
    @Published var query: String = ""
    
    /// Results shown in the UI.
    @Published var results: [Game] = []
    
    /// Loading state for API calls
    @Published var isLoading: Bool = false
    
    /// Error message from API or search
    @Published var errorMessage: String?
    
    /// Has the user actually run a search yet?
    @Published var hasSearched: Bool = false
    
    // MARK: - Search
    
    /// Searches for games using the RAWG API.
    func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If the query is very short, don't search and reset state.
        guard trimmed.count >= 2 else {
            results = []
            hasSearched = false
            errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        hasSearched = true
        
        // Call RAWG API via GameService
        gameService.searchGames(query: trimmed) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let games):
                    self?.results = games
                    self?.errorMessage = nil
                    if games.isEmpty {
                        self?.errorMessage = "No games found. Try a different search term."
                    }
                case .failure(let error):
                    self?.results = []
                    self?.errorMessage = self?.userFriendlyErrorMessage(from: error)
                }
            }
        }
    }
    
    /// Clears the current query and results.
    func clear() {
        query = ""
        results = []
        errorMessage = nil
        hasSearched = false
        isLoading = false
    }
    
    // MARK: - Error Handling
    
    /// Converts GameServiceError to user-friendly messages.
    private func userFriendlyErrorMessage(from error: GameServiceError) -> String {
        switch error {
        case .apiKeyMissing:
            return "API key not configured. Please contact support."
        case .invalidURL:
            return "Invalid search. Please try again."
        case .requestFailed:
            return "Network error. Please check your connection and try again."
        case .decodingFailed:
            return "Could not process game data. Please try again."
        }
    }
}
