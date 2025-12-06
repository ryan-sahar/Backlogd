//
//  GameDetailView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Detail screen for a single game.
//  Shows game info, your personal log status, rating, review,
//  and allows editing via the GameLogSheet.
//

import SwiftUI

struct GameDetailView: View {
    
    let game: Game
    
    @EnvironmentObject var logStore: GameLogStore
    @State private var isShowingLogSheet = false
    @State private var isShowingShareSheet = false
    @State private var shareMessage = ""
    @State private var displayedGame: Game
    @State private var isFetchingDetails = false
    
    init(game: Game) {
        self.game = game
        _displayedGame = State(initialValue: game)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Cover
                if let coverURL = displayedGame.coverURL {
                    AsyncImage(url: URL(string: coverURL)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.backlogCard)
                                .frame(height: 200)
                                .overlay(
                                    ProgressView()
                                        .tint(.backlogAccentRed)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(20)
                        case .failure:
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.backlogCard)
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.backlogSecondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.top)
                } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.backlogCard)
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.backlogSecondary)
                    )
                    .padding(.top)
                }
                
                // Title / meta
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayedGame.title)
                        .font(.title.bold())
                        .foregroundColor(.backlogPrimary)
                    
                    if !displayedGame.platforms.isEmpty {
                        Text(displayedGame.platforms.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundColor(.backlogSecondary)
                    }
                    
                    if !displayedGame.genres.isEmpty {
                        Text(displayedGame.genres.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundColor(.backlogSecondary)
                    }
                }
                
                Divider().background(Color.backlogCard)
                
                // About
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                        .foregroundColor(.backlogPrimary)
                    
                    if isFetchingDetails {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.backlogAccentRed)
                            Text("Loading description...")
                                .font(.body)
                                .foregroundColor(.backlogSecondary)
                        }
                    } else {
                        Text(displayedGame.description)
                            .font(.body)
                            .foregroundColor(.backlogSecondary)
                    }
                }
                
                Divider().background(Color.backlogCard)
                
                // Log
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Log")
                        .font(.headline)
                        .foregroundColor(.backlogPrimary)
                    
                    if let log = logStore.log(for: displayedGame.id) {
                        NavigationLink {
                            GameReviewView(game: displayedGame, log: log)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(log.status.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.backlogPrimary)
                                
                                if let rating = log.rating {
                                    Text("Rating: \(rating)/10")
                                        .font(.subheadline)
                                        .foregroundColor(.backlogSecondary)
                                }
                                
                                if let text = log.reviewText, !text.isEmpty {
                                    Text("“\(text)”")
                                        .font(.footnote)
                                        .foregroundColor(.backlogSecondary)
                                        .lineLimit(3)
                                }
                                
                                // ✅ keep this as a single line
                                Text("Last updated \(log.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.backlogTertiary)
                            }
                            .padding()
                            .background(Color.backlogCard)
                            .cornerRadius(12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                    } else {
                        Text("You haven’t logged this game yet. Mark your status, rate it, or write a short review.")
                            .font(.footnote)
                            .foregroundColor(.backlogSecondary)
                    }
                    
                    Button {
                        isShowingLogSheet = true
                    } label: {
                        Text("Log / Review")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.backlogAccentRed)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
        .background(Color.backlogBackground.ignoresSafeArea())
        .navigationTitle(displayedGame.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    prepareShareContent()
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShowingLogSheet) {
            GameLogSheet(game: displayedGame)
                .environmentObject(logStore)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(items: [shareMessage]) { completed in
                if completed {
                    print("Review shared successfully")
                }
            }
        }
        .onAppear {
            prepareShareContent()
            // If description is missing or placeholder, fetch full game details
            if displayedGame.description == "No description available." || displayedGame.description.isEmpty {
                fetchGameDetails()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchGameDetails() {
        // Don't fetch if already fetching
        guard !isFetchingDetails else { return }
        
        isFetchingDetails = true
        GameService.shared.fetchGame(byID: displayedGame.id) { result in
            DispatchQueue.main.async {
                isFetchingDetails = false
                switch result {
                case .success(let fetchedGame):
                    displayedGame = fetchedGame
                    // Update the log if it exists to store the full game metadata
                    if let log = logStore.log(for: fetchedGame.id) {
                        logStore.upsertLog(
                            for: fetchedGame,
                            status: log.status,
                            rating: log.rating,
                            reviewText: log.reviewText,
                            playtimeHours: log.playtimeHours,
                            location: log.location
                        )
                    }
                case .failure:
                    // Keep using the original game data
                    break
                }
            }
        }
    }
    
    private func prepareShareContent() {
        if let log = logStore.log(for: displayedGame.id) {
            var shareText = "Just reviewed \(displayedGame.title) on Backlog'd!\n\n"
            
            shareText += "Status: \(log.status.rawValue)\n"
            
            if let rating = log.rating {
                shareText += "Rating: \(rating)/10\n"
            }
            
            if let reviewText = log.reviewText, !reviewText.isEmpty {
                shareText += "\n\(reviewText)"
            }
            
            shareMessage = shareText
        } else {
            shareMessage = "Check out \(displayedGame.title) on Backlog'd!"
        }
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: Game(
            id: 1,
            title: "Elden Ring",
            platforms: ["PS5", "Xbox Series X|S", "PC"],
            genres: ["Action RPG", "Open World"],
            description: "A dark fantasy open-world action RPG from FromSoftware.",
            releaseYear: 2022
        ))
            .environmentObject(GameLogStore())
    }
}
