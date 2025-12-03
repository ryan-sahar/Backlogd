//
//  ProfileViewModel.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  View model for the Profile screen.
//  Calculates statistics from user's game logs.
//

import Foundation
import Combine
import FirebaseAuth

/// View model for user profile and statistics.
final class ProfileViewModel: ObservableObject {
    
    @Published var user: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Stats computed from logs
    @Published var totalGamesLogged: Int = 0
    @Published var completedCount: Int = 0
    @Published var averageRating: Double = 0.0
    @Published var totalPlaytimeHours: Double = 0.0
    @Published var favoriteGenres: [String] = []
    @Published var favoritePlatforms: [String] = []
    
    private let userService = UserService.shared
    private let logStore: GameLogStore
    
    init(logStore: GameLogStore) {
        self.logStore = logStore
        
        // Calculate initial stats
        calculateStats()
        
        // Observe log changes to recalculate stats
        logStore.$logs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.calculateStats()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Loads user profile data. Creates user document if it doesn't exist.
    func loadUser(userID: String) {
        isLoading = true
        errorMessage = nil
        
        userService.fetchUser(userID: userID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    print("✅ ProfileViewModel: User loaded. photoURL: \(user.photoURL ?? "nil")")
                    self?.isLoading = false
                    self?.user = user
                case .failure:
                    // If user doesn't exist, create it
                    print("⚠️ ProfileViewModel: User not found, creating user document...")
                    let displayName = Auth.auth().currentUser?.displayName ?? "User"
                    self?.userService.createUserIfNeeded(userID: userID, displayName: displayName) { createResult in
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            switch createResult {
                            case .success:
                                // Retry loading user
                                self?.loadUser(userID: userID)
                            case .failure(let createError):
                                print("❌ ProfileViewModel: Failed to create user: \(createError.localizedDescription)")
                                self?.errorMessage = createError.localizedDescription
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Calculates statistics from the current logs.
    private func calculateStats() {
        let logs = logStore.logs
        
        // Basic counts
        totalGamesLogged = logs.count
        completedCount = logs.filter { $0.status == .completed }.count
        
        // Average rating (only from logs with ratings)
        let ratingsWithValues = logs.compactMap { $0.rating }
        if !ratingsWithValues.isEmpty {
            let sum = ratingsWithValues.reduce(0, +)
            averageRating = Double(sum) / Double(ratingsWithValues.count)
        } else {
            averageRating = 0.0
        }
        
        // Total playtime
        totalPlaytimeHours = logs.compactMap { $0.playtimeHours }.reduce(0, +)
        
        // Favorite genres and platforms (would need game data to compute)
        // For now, we'll leave these empty until we have a game catalog
        favoriteGenres = []
        favoritePlatforms = []
    }
    
    /// Formatted average rating string.
    var averageRatingString: String {
        if averageRating > 0 {
            return String(format: "%.1f", averageRating)
        }
        return "—"
    }
    
    /// Formatted total playtime string.
    var totalPlaytimeString: String {
        if totalPlaytimeHours > 0 {
            if totalPlaytimeHours < 1 {
                return String(format: "%.1f hours", totalPlaytimeHours)
            } else if totalPlaytimeHours < 100 {
                return String(format: "%.1f hours", totalPlaytimeHours)
            } else {
                return String(format: "%.0f hours", totalPlaytimeHours)
            }
        }
        return "—"
    }
    
    /// Updates the user's profile photo URL.
    func updatePhotoURL(_ photoURL: String, userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("📝 ProfileViewModel: Updating photoURL to: \(photoURL)")
        userService.updateUser(userID: userID, photoURL: photoURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ ProfileViewModel: photoURL updated in Firestore, reloading user...")
                    // Reload user to get updated data
                    self?.loadUser(userID: userID)
                    completion(.success(()))
                case .failure(let error):
                    print("❌ ProfileViewModel: Failed to update photoURL: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
}

