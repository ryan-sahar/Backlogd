//
//  GameReviewView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Shows a single log/review for a game,
//  with an Edit Log button that opens the log sheet.
//

import SwiftUI

struct GameReviewView: View {
    
    let game: Game
    let log: GameLog
    
    @EnvironmentObject var logStore: GameLogStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingEditSheet = false
    @State private var isShowingShareSheet = false
    @State private var isShowingDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Cover - clickable to navigate to game detail
                NavigationLink {
                    GameDetailView(game: game)
                        .environmentObject(logStore)
                } label: {
                    if let coverURL = game.coverURL, let url = URL(string: coverURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.backlogCard)
                                    .frame(height: 220)
                                    .overlay(
                                        ProgressView()
                                            .tint(.backlogAccentRed)
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 220)
                                    .clipped()
                                    .cornerRadius(20)
                            case .failure:
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.backlogCard)
                                    .frame(height: 220)
                                    .overlay(
                                        Image(systemName: "gamecontroller.fill")
                                            .font(.system(size: 56))
                                            .foregroundColor(.backlogSecondary)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.backlogCard)
                            .frame(height: 220)
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 56))
                                    .foregroundColor(.backlogSecondary)
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top)
                
                // Game info
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
                
                // Log summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Log")
                        .font(.headline)
                        .foregroundColor(.backlogPrimary)
                    
                    HStack(spacing: 8) {
                        Text(log.status.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.backlogCard)
                            .cornerRadius(8)
                            .foregroundColor(.backlogPrimary)
                        
                        if let rating = log.rating {
                            Text("★ \(rating)/10")
                                .font(.subheadline)
                                .foregroundColor(.backlogSecondary)
                        }
                    }
                    
                    // ✅ keep this as a single line
                    Text("Last updated \(log.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.backlogTertiary)
                }
                
                // Review text
                if let text = log.reviewText, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review")
                            .font(.headline)
                            .foregroundColor(.backlogPrimary)
                        
                        Text(text)
                            .font(.body)
                            .foregroundColor(.backlogSecondary)
                    }
                }
                
                Spacer(minLength: 24)
                
                Button {
                    isShowingEditSheet = true
                } label: {
                    Text("Edit Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.backlogAccentRed)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                
                Button {
                    isShowingDeleteAlert = true
                } label: {
                    Text("Delete Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(16)
                }
                .disabled(isDeleting)
            }
            .padding(.horizontal)
        }
        .background(Color.backlogBackground.ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet, onDismiss: { dismiss() }) {
            GameLogSheet(game: game)
                .environmentObject(logStore)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(items: [generateShareText()]) { completed in
                if completed {
                    print("Review shared successfully")
                }
            }
        }
        .alert("Delete Log", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLog()
            }
        } message: {
            Text("Are you sure you want to delete your log for \(game.title)? This action cannot be undone.")
        }
    }
    
    private func deleteLog() {
        isDeleting = true
        logStore.deleteLog(log)
        // Small delay to allow Firestore deletion to process, then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDeleting = false
            dismiss()
        }
    }
    
    private func generateShareText() -> String {
        var shareText = "Just reviewed \(game.title) on Backlog'd!\n\n"
        
        shareText += "Status: \(log.status.rawValue)\n"
        
        if let rating = log.rating {
            shareText += "Rating: \(rating)/10\n"
        }
        
        if let reviewText = log.reviewText, !reviewText.isEmpty {
            shareText += "\n\(reviewText)"
        }
        
        return shareText
    }
}

#Preview {
    let previewGame = Game(
        id: 1,
        title: "Elden Ring",
        platforms: ["PS5", "Xbox Series X|S", "PC"],
        genres: ["Action RPG", "Open World"],
        description: "A dark fantasy open-world action RPG from FromSoftware.",
        releaseYear: 2022
    )
    return NavigationStack {
        GameReviewView(
            game: previewGame,
            log: GameLog(
                id: UUID().uuidString,
                userID: "preview-user",
                gameId: previewGame.id,
                status: .completed,
                rating: 9,
                reviewText: "Insanely challenging",
                createdAt: .now,
                updatedAt: .now
            )
        )
        .environmentObject(GameLogStore())
    }
}
