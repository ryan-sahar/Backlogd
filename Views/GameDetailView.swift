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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Cover
                if let coverURL = game.coverURL {
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
                    Text(game.title)
                        .font(.title.bold())
                        .foregroundColor(.backlogPrimary)
                    
                    if !game.platforms.isEmpty {
                        Text(game.platforms.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundColor(.backlogSecondary)
                    }
                    
                    if !game.genres.isEmpty {
                        Text(game.genres.joined(separator: " · "))
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
                    
                    Text(game.description)
                        .font(.body)
                        .foregroundColor(.backlogSecondary)
                }
                
                Divider().background(Color.backlogCard)
                
                // Log
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Log")
                        .font(.headline)
                        .foregroundColor(.backlogPrimary)
                    
                    if let log = logStore.log(for: game.id) {
                        NavigationLink {
                            GameReviewView(game: game, log: log)
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
        .navigationTitle(game.title)
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
            GameLogSheet(game: game)
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
        }
    }
    
    private func prepareShareContent() {
        if let log = logStore.log(for: game.id) {
            var shareText = "Just reviewed \(game.title) on Backlog'd!\n\n"
            
            shareText += "Status: \(log.status.rawValue)\n"
            
            if let rating = log.rating {
                shareText += "Rating: \(rating)/10\n"
            }
            
            if let reviewText = log.reviewText, !reviewText.isEmpty {
                shareText += "\n\(reviewText)"
            }
            
            shareMessage = shareText
        } else {
            shareMessage = "Check out \(game.title) on Backlog'd!"
        }
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: Game.mockGames[0])
            .environmentObject(GameLogStore())
    }
}
