//
//  LoggedGamesView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Lists all games you've logged, grouped by status.
//

import SwiftUI

struct LoggedGamesView: View {
    
    @EnvironmentObject var logStore: GameLogStore
    
    // Group logs by status in a fixed order
    private var logsByStatus: [(status: GameStatus, logs: [GameLog])] {
        let grouped = Dictionary(grouping: logStore.logs, by: { $0.status })
        let order: [GameStatus] = [.playing, .notStarted, .completed, .shelved, .wishlist]
        
        return order.compactMap { status in
            guard let logs = grouped[status], !logs.isEmpty else { return nil }
            return (status, logs)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                if logStore.logs.isEmpty {
                    emptyState
                } else {
                    logsList
                }
            }
            .navigationTitle("Lists")
        }
    }
    
    // MARK: - Subviews
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No logged games yet")
                .font(.headline)
                .foregroundColor(.backlogPrimary)
            Text("Log a game from the Search tab, then it will show up here in your backlog.")
                .font(.subheadline)
                .foregroundColor(.backlogSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var logsList: some View {
        List {
            ForEach(logsByStatus, id: \.status) { group in
                Section(group.status.rawValue) {
                    ForEach(group.logs) { log in
                        
                        // Break this into a tiny helper to keep type-checking simple
                        LoggedGameRowContainer(log: log)
                    }
                }
                .headerProminence(.increased)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.backlogBackground)
        .listStyle(.insetGrouped)
    }
}

/// Thin wrapper so the compiler has a tiny, easy-to-infer body
private struct LoggedGameRowContainer: View {
    let log: GameLog
    
    var body: some View {
        // Look up the game in your local mock DB
        let game = Game.mockGames.first { $0.id == log.gameId }
        
        if let game {
            NavigationLink {
                GameReviewView(game: game, log: log)
            } label: {
                LoggedGameRowView(game: game, log: log)
            }
        } else {
            LoggedGameRowView(game: nil, log: log)
        }
    }
}

// MARK: - Row View

struct LoggedGameRowView: View {
    
    let game: Game?
    let log: GameLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.backlogCard)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "gamecontroller")
                        .foregroundColor(.backlogSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game?.title ?? "Unknown Game")
                    .font(.headline)
                    .foregroundColor(.backlogPrimary)
                
                if let platforms = game?.platforms, !platforms.isEmpty {
                    Text(platforms.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.backlogSecondary)
                }
                
                HStack(spacing: 8) {
                    Text(log.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.backlogCard)
                        .cornerRadius(6)
                        .foregroundColor(.backlogPrimary)
                    
                    if let rating = log.rating {
                        Text("★ \(rating)/10")
                            .font(.caption)
                            .foregroundColor(.backlogSecondary)
                    }
                }
                
                if let text = log.reviewText, !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.backlogSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.backlogBackground)
    }
}

#Preview {
    LoggedGamesView()
        .environmentObject(GameLogStore())
        .environmentObject(AuthViewModel())
}
