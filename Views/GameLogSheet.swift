//
//  GameLogSheet.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Sheet for logging / reviewing a game.
//

import SwiftUI
import FirebaseFirestore

struct GameLogSheet: View {
    
    let game: Game
    
    @EnvironmentObject var logStore: GameLogStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var status: GameStatus = .notStarted
    @State private var rating: Int = 7
    @State private var hasRating: Bool = false
    @State private var reviewText: String = ""
    @State private var playtimeHours: Double = 0
    @State private var hasPlaytime: Bool = false
    @State private var attachLocation: Bool = false
    @State private var isGettingLocation = false
    @State private var locationError: String?
    
    @StateObject private var locationService = LocationService.shared
    
    @State private var didLoadExistingLog = false
    @State private var isSaving = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                Form {
                    Section("Game") {
                        Text(game.title)
                            .foregroundColor(.backlogPrimary)
                        if !game.platforms.isEmpty {
                            Text(game.platforms.joined(separator: " · "))
                                .foregroundColor(.backlogSecondary)
                        }
                    }
                    
                    Section("Status") {
                        Picker("Status", selection: $status) {
                            ForEach(GameStatus.allCases) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                    }
                    
                    Section("Rating") {
                        Toggle("Add rating", isOn: $hasRating)
                        
                        if hasRating {
                            Stepper(value: $rating, in: 1...10) {
                                Text("Rating: \(rating)/10")
                            }
                        } else {
                            Text("Optional — turn on to rate this game.")
                                .font(.footnote)
                                .foregroundColor(.backlogSecondary)
                        }
                    }
                    
                    Section("Playtime") {
                        Toggle("Add playtime", isOn: $hasPlaytime)
                        
                        if hasPlaytime {
                            Stepper(value: $playtimeHours, in: 0...10000, step: 0.5) {
                                Text("Hours: \(playtimeHours, specifier: "%.1f")")
                            }
                        } else {
                            Text("Optional — track how long you've played.")
                                .font(.footnote)
                                .foregroundColor(.backlogSecondary)
                        }
                    }
                    
                    Section("Location") {
                        Toggle("Attach current location", isOn: $attachLocation)
                            .onChange(of: attachLocation) { oldValue, newValue in
                                if newValue {
                                    requestLocation()
                                }
                            }
                        
                        if isGettingLocation {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Getting location...")
                                    .font(.footnote)
                                    .foregroundColor(.backlogSecondary)
                            }
                        }
                        
                        if let locationError = locationError {
                            Text(locationError)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        
                        if attachLocation && !isGettingLocation && locationError == nil {
                            Text("Location will be attached to this log.")
                                .font(.footnote)
                                .foregroundColor(.backlogSecondary)
                        }
                    }
                    
                    Section("Review") {
                        TextEditor(text: $reviewText)
                            .frame(minHeight: 120)
                        Text("Optional — share quick thoughts or favorite moments.")
                            .font(.footnote)
                            .foregroundColor(.backlogSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Log Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLog()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear(perform: loadExistingLogIfNeeded)
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
            .alert("Save Error", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") {
                    saveError = nil
                }
            } message: {
                if let error = saveError {
                    Text(error)
                }
            }
        }
    }
    
    private func loadExistingLogIfNeeded() {
        guard !didLoadExistingLog else { return }
        didLoadExistingLog = true
        
        if let existing = logStore.log(for: game.id) {
            status = existing.status
            if let existingRating = existing.rating {
                rating = existingRating
                hasRating = true
            }
            reviewText = existing.reviewText ?? ""
            if let existingPlaytime = existing.playtimeHours {
                playtimeHours = existingPlaytime
                hasPlaytime = true
            }
            attachLocation = existing.location != nil
        }
    }
    
    private func requestLocation() {
        guard attachLocation else { return }
        
        isGettingLocation = true
        locationError = nil
        
        locationService.getCurrentLocation { result in
            DispatchQueue.main.async {
                isGettingLocation = false
                switch result {
                case .success:
                    // Location stored in locationService.currentLocation
                    break
                case .failure(let error):
                    locationError = error.localizedDescription
                    attachLocation = false
                }
            }
        }
    }
    
    private func saveLog() {
        guard !isSaving else { return }
        
        isSaving = true
        saveError = nil
        
        let finalRating: Int? = hasRating ? rating : nil
        let finalPlaytime: Double? = hasPlaytime ? playtimeHours : nil
        let location: GeoPoint? = attachLocation && locationService.currentLocation != nil
            ? locationService.locationToGeoPoint(locationService.currentLocation!)
            : nil
        
        // Call upsertLog with completion handler
        logStore.upsertLogWithCompletion(
            for: game,
            status: status,
            rating: finalRating,
            reviewText: reviewText.trimmingCharacters(in: .whitespacesAndNewlines),
            playtimeHours: finalPlaytime,
            location: location
        ) { [self] success, errorMessage in
            isSaving = false
            
            if success {
        dismiss()
            } else {
                saveError = errorMessage ?? "Failed to save log. Please try again."
            }
        }
    }
}

#Preview {
    GameLogSheet(game: Game(
        id: 1,
        title: "Elden Ring",
        platforms: ["PS5", "Xbox Series X|S", "PC"],
        genres: ["Action RPG", "Open World"],
        description: "A dark fantasy open-world action RPG from FromSoftware.",
        releaseYear: 2022
    ))
        .environmentObject(GameLogStore())
}
