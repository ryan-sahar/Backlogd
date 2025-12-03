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
                                        // For now we look up the Game from the mock list.
                                        // Later, when we use a real API, we'll have a proper catalog.
                                        if let game = Game.mockGames.first(where: { $0.id == log.gameId }) {
                                            NavigationLink {
                                                GameReviewView(game: game, log: log)
                                            } label: {
                                                LoggedGameRow(game: game, log: log)
                                            }
                                        }
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

/// Re-usable row that shows basic info about a logged game.
struct LoggedGameRow: View {
    
    let game: Game
    let log: GameLog
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple cover placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "gamecontroller")
                        .foregroundColor(.secondary)
                )
            
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
    store.upsertLog(
        for: Game.mockGames[0],
        status: .completed,
        rating: 9,
        reviewText: "Insanely good combat."
    )
    store.upsertLog(
        for: Game.mockGames[1],
        status: .wishlist,
        rating: nil,
        reviewText: nil
    )
    
    return ListsView()
        .environmentObject(store)
}
