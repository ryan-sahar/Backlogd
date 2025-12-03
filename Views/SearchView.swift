//
//  SearchView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Search screen where users can look up games.
//  Uses RAWG API via SearchViewModel and GameService.
//

import SwiftUI

struct SearchView: View {
    
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var speechService = SpeechService.shared
    
    @State private var isShowingPermissionAlert = false
    @State private var speechError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                VStack {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.backlogSecondary)
                        
                        TextField("Search games", text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(.backlogPrimary)
                        
                        // Mic button for voice search
                        Button {
                            handleMicButtonTap()
                        } label: {
                            Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                                .foregroundColor(speechService.isRecording ? .backlogAccentRed : .backlogSecondary)
                        }
                        
                        if !viewModel.query.isEmpty {
                            Button {
                                viewModel.query = ""
                                viewModel.results = []
                                viewModel.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.backlogSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.backlogCard)
                    .cornerRadius(12)
                    .padding([.horizontal, .top])
                    
                    // Explicit search button (to avoid spam API calls)
                    Button {
                        viewModel.performSearch()
                    } label: {
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Searching...")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.backlogAccentRed.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        } else {
                            Text("Search")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.backlogAccentRed)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // Speech recording indicator
                    if speechService.isRecording {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.backlogAccentRed)
                            Text("Listening...")
                                .foregroundColor(.backlogAccentRed)
                                .font(.subheadline)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Error messages
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                    
                    if let speechError = speechError {
                        Text(speechError)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                    
                    // Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Searching games…")
                            .foregroundColor(.backlogPrimary)
                        Spacer()
                    } else if viewModel.results.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            if !viewModel.hasSearched {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.backlogSecondary)
                                Text("Search for games")
                                    .font(.headline)
                                    .foregroundColor(.backlogPrimary)
                                Text("Type a game name and tap Search to find games from RAWG.")
                                    .font(.subheadline)
                                    .foregroundColor(.backlogSecondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 48))
                                    .foregroundColor(.backlogSecondary)
                                Text("No games found")
                                    .font(.headline)
                                    .foregroundColor(.backlogPrimary)
                                Text("Try a different search term or check your connection.")
                                    .font(.subheadline)
                                    .foregroundColor(.backlogSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal)
                        Spacer()
                    } else {
                        List(viewModel.results) { game in
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                GameRowView(game: game)
                            }
                            .listRowBackground(Color.backlogCard)
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.backlogBackground)
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Search")
            .alert("Microphone Permission Required", isPresented: $isShowingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to use voice search.")
            }
            .onAppear {
                speechService.checkAuthorizationStatus()
            }
        }
    }
    
    // MARK: - Speech Handling
    
    private func handleMicButtonTap() {
        if speechService.isRecording {
            // Stop recording and get the transcribed text
            speechService.stopRecordingManually()
        } else {
            speechError = nil
            speechService.startRecording { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcribedText):
                        if !transcribedText.isEmpty {
                            viewModel.query = transcribedText
                            // Automatically trigger search after voice input
                            viewModel.performSearch()
                        } else {
                            speechError = "No speech detected. Please try again."
                        }
                    case .failure(let error):
                        if let speechError = error as? SpeechServiceError {
                            switch speechError {
                            case .permissionDenied:
                                isShowingPermissionAlert = true
                            case .recognitionFailed:
                                // Only show error if it's not due to empty transcription
                                if speechService.isRecording {
                                    self.speechError = nil // User might still be speaking
                                } else {
                                    self.speechError = "Could not recognize speech. Please try again."
                                }
                            default:
                                self.speechError = speechError.localizedDescription
                            }
                        } else {
                            self.speechError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}

struct GameRowView: View {
    let game: Game
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Game cover
            if let coverURL = game.coverURL {
                AsyncImage(url: URL(string: coverURL)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.backlogCard)
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.backlogCard)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "gamecontroller")
                                    .foregroundColor(.backlogSecondary)
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.backlogCard)
                            .frame(width: 56, height: 56)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.backlogCard)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.backlogSecondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .foregroundColor(.backlogPrimary)
                
                if !game.platforms.isEmpty {
                    Text(game.platforms.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.backlogSecondary)
                }
                
                if !game.genres.isEmpty {
                    Text(game.genres.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.backlogTertiary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchView()
}
