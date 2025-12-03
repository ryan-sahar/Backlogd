//
//  FeedView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Feed screen showing recent game logs.
//  For MVP, shows the user's own recent logs.
//

import SwiftUI

struct FeedView: View {
    
    @EnvironmentObject var logStore: GameLogStore
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                if logStore.isLoading {
                    ProgressView("Loading your activity...")
                        .foregroundColor(.backlogPrimary)
                } else if let error = logStore.errorMessage {
                    errorState(error)
                } else if logStore.logs.isEmpty {
                    emptyState
                } else {
                    feedList
                }
            }
            .navigationTitle("Feed")
        }
    }
    
    // MARK: - Subviews
    
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error loading activity")
                .font(.headline)
                .foregroundColor(.backlogPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.backlogSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundColor(.backlogSecondary)
            
            Text("No activity yet")
                .font(.headline)
                .foregroundColor(.backlogPrimary)
            
            Text("Log some games to see your activity feed here.")
                .font(.subheadline)
                .foregroundColor(.backlogSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var feedList: some View {
        List {
            ForEach(logStore.logs.prefix(20)) { log in
                // Look up the game from mock data (later from Firestore cache)
                if let game = Game.mockGames.first(where: { $0.id == log.gameId }) {
                    NavigationLink {
                        GameReviewView(game: game, log: log)
                    } label: {
                        FeedLogRow(game: game, log: log)
                    }
                    .listRowBackground(Color.backlogCard)
                } else {
                    // Fallback: show log even without game data
                    NavigationLink {
                        FeedLogDetailView(log: log)
                    } label: {
                        FeedLogRowFallback(log: log)
                    }
                    .listRowBackground(Color.backlogCard)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.backlogBackground)
        .listStyle(.plain)
    }
}

// MARK: - Feed Log Row

private struct FeedLogRow: View {
    let game: Game
    let log: GameLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Game cover placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.backlogCard)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.backlogSecondary)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                // Game title
                Text(game.title)
                    .font(.headline)
                    .foregroundColor(.backlogPrimary)
                
                // Status and rating
                HStack(spacing: 8) {
                    Text(log.status.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.backlogBackground)
                        .cornerRadius(6)
                        .foregroundColor(.backlogPrimary)
                    
                    if let rating = log.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text("\(rating)/10")
                                .font(.subheadline)
                        }
                        .foregroundColor(.backlogAccentRed)
                    }
                }
                
                // Review snippet
                if let reviewText = log.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.caption)
                        .foregroundColor(.backlogSecondary)
                        .lineLimit(2)
                }
                
                // Timestamp
                Text(log.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.backlogTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Fallback Views

private struct FeedLogRowFallback: View {
    let log: GameLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.backlogCard)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.backlogSecondary)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Game ID: \(log.gameId)")
                    .font(.headline)
                    .foregroundColor(.backlogPrimary)
                
                HStack(spacing: 8) {
                    Text(log.status.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.backlogBackground)
                        .cornerRadius(6)
                        .foregroundColor(.backlogPrimary)
                    
                    if let rating = log.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text("\(rating)/10")
                                .font(.subheadline)
                        }
                        .foregroundColor(.backlogAccentRed)
                    }
                }
                
                if let reviewText = log.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.caption)
                        .foregroundColor(.backlogSecondary)
                        .lineLimit(2)
                }
                
                Text(log.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.backlogTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

private struct FeedLogDetailView: View {
    let log: GameLog
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Game ID: \(log.gameId)")
                    .font(.title.bold())
                    .foregroundColor(.backlogPrimary)
                
                Text("Status: \(log.status.rawValue)")
                    .font(.headline)
                    .foregroundColor(.backlogSecondary)
                
                if let rating = log.rating {
                    Text("Rating: \(rating)/10")
                        .font(.headline)
                        .foregroundColor(.backlogAccentRed)
                }
                
                if let reviewText = log.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.body)
                        .foregroundColor(.backlogPrimary)
                }
            }
            .padding()
        }
        .navigationTitle("Log Details")
        .background(Color.backlogBackground)
    }
}

#Preview {
    FeedView()
        .environmentObject(GameLogStore())
        .environmentObject(AuthViewModel())
}

