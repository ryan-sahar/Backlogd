//
//  ListsView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Shows your logged games grouped by status
//  (Playing, Completed, Wishlist, etc).
//

import SwiftUI

struct ListsView: View {
    
    @EnvironmentObject var logStore: GameLogStore
    
    var body: some View {
        NavigationStack {
            Group {
                if logStore.logs.isEmpty {
                    // Empty state when the user hasn't logged anything yet.
                    VStack(spacing: 16) {
                        Text("No games logged yet")
                            .font(.headline)
                        
                        Text("Search for a game, log it, and your backlog will show up here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // One section per status (Not Started, Playing, etc.)
                        ForEach(GameStatus.allCases) { status in
                            let logsForStatus = logStore.logs(for: status)
                            
                            if !logsForStatus.isEmpty {
                                Section(status.rawValue) {
                                    ForEach(logsForStatus) { log in
                                        LoggedGameRowWithFetch(log: log)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Lists")
        }
    }
}

/// Wrapper that fetches game data if missing
private struct LoggedGameRowWithFetch: View {
    let log: GameLog
    @EnvironmentObject var logStore: GameLogStore
    @State private var fetchedGame: Game?
    @State private var isFetching = false
    
    var body: some View {
        let game = fetchedGame ?? log.toGame()
        NavigationLink {
            GameReviewView(game: game, log: log)
        } label: {
            LoggedGameRow(game: game, log: log)
        }
        .onAppear {
            // If log is missing game title, fetch it from RAWG
            if log.gameTitle == nil && !isFetching {
                fetchGameDetails()
            } else {
                fetchedGame = log.toGame()
            }
        }
    }
    
    private func fetchGameDetails() {
        isFetching = true
        GameService.shared.fetchGame(byID: log.gameId) { result in
            DispatchQueue.main.async {
                isFetching = false
                switch result {
                case .success(let game):
                    fetchedGame = game
                    // Update the log in Firestore with the fetched data
                    // upsertLog will automatically store all game metadata (title, coverURL, description, platforms, genres, releaseYear)
                    logStore.upsertLog(
                        for: game,
                        status: log.status,
                        rating: log.rating,
                        reviewText: log.reviewText,
                        playtimeHours: log.playtimeHours,
                        location: log.location
                    )
                case .failure:
                    fetchedGame = log.toGame()
                }
            }
        }
    }
}

/// Re-usable row that shows basic info about a logged game.
struct LoggedGameRow: View {
    
    let game: Game
    let log: GameLog
    
    var body: some View {
        HStack(spacing: 12) {
            // Game cover image
            if let coverURL = game.coverURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 56, height: 56)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.backlogAccentRed)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .cornerRadius(10)
                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "gamecontroller")
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 56, height: 56)
                    }
                }
            } else {
                // Placeholder when no cover URL
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(log.status.rawValue)
                        .font(.subheadline)
                    
                    if let rating = log.rating {
                        Text("• \(rating)/10")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.secondary)
                
                if let text = log.reviewText, !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let store = GameLogStore()
    // Seed some fake logs for preview
    let game1 = Game(
        id: 1,
        title: "Elden Ring",
        platforms: ["PS5", "PC"],
        genres: ["Action RPG"],
        description: "A dark fantasy action RPG."
    )
    let game2 = Game(
        id: 2,
        title: "The Legend of Zelda",
        platforms: ["Nintendo Switch"],
        genres: ["Action Adventure"],
        description: "An epic adventure game."
    )
    store.upsertLog(
        for: game1,
        status: .completed,
        rating: 9,
        reviewText: "Insanely good combat."
    )
    store.upsertLog(
        for: game2,
        status: .wishlist,
        rating: nil,
        reviewText: nil
    )
    
    return ListsView()
        .environmentObject(store)
}
