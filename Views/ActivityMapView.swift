//
//  ActivityMapView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Map view showing logged game locations using MapKit.
//  Groups nearby locations together and allows naming them.
//

import SwiftUI
import MapKit
import FirebaseFirestore
import CoreLocation

struct ActivityMapView: View {
    
    @EnvironmentObject var logStore: GameLogStore
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    @State private var selectedLocationGroupID: String?
    @State private var namedLocations: [NamedLocation] = []
    @State private var isLoadingNamedLocations = false
    @State private var locationGroups: [LocationGroup] = [] // Store groups as state to ensure proper updates
    @State private var mapRefreshID: UUID = UUID() // Force map refresh when this changes
    
    private var selectedLocationGroup: LocationGroup? {
        guard let selectedLocationGroupID = selectedLocationGroupID else { return nil }
        // Always get the latest group from locationGroups state
        return locationGroups.first { $0.id == selectedLocationGroupID }
    }
    
    /// Updates locationGroups by grouping logs and applying named locations
    private func updateLocationGroups() {
        let logsWithLocations = logStore.logs.filter { $0.location != nil }
        let groups = LocationGroup.groupLogs(logsWithLocations, radiusMeters: 100.0)
        
        // Apply named locations to groups
        locationGroups = groups.map { group in
            var updatedGroup = group
            if let namedLocation = namedLocations.first(where: { location in
                location.matches(coordinate: group.coordinate)
            }) {
                updatedGroup.name = namedLocation.name
            } else {
                // Clear name if no named location matches
                updatedGroup.name = nil
            }
            return updatedGroup
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                Map(position: $cameraPosition, selection: $selectedLocationGroupID) {
                    ForEach(locationGroups) { group in
                        Annotation(
                            group.id,
                            coordinate: group.coordinate
                        ) {
                            Button {
                                selectedLocationGroupID = group.id
                            } label: {
                                VStack(spacing: 4) {
                                    // Show count badge if multiple games
                                    ZStack {
                                        Circle()
                                            .fill(Color.backlogAccentRed)
                                            .frame(width: 40, height: 40)
                                        
                                        if group.gameCount > 1 {
                                            Text("\(group.gameCount)")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                        } else {
                                            Image(systemName: "gamecontroller.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 18))
                                        }
                                    }
                                    .shadow(radius: 4)
                                    
                                    // Location name or game title
                                    Text(displayName(for: group))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.backlogCard.opacity(0.95))
                                        .cornerRadius(6)
                                        .foregroundColor(.backlogPrimary)
                                }
                            }
                        }
                    }
                }
                .id(mapRefreshID) // Force map refresh when this changes
                .sheet(item: Binding(
                    get: { selectedLocationGroup },
                    set: { _ in selectedLocationGroupID = nil }
                )) { group in
                    locationGamesSheetContent(for: group)
                }
            }
            .navigationTitle("Game Locations")
            .onAppear {
                updateCameraPosition()
                loadNamedLocations()
                updateLocationGroups()
            }
            .onChange(of: namedLocations) { oldValue, newValue in
                // Update groups when named locations change
                updateLocationGroups()
                // Force map refresh to show updated annotation names
                mapRefreshID = UUID()
            }
            .onChange(of: logStore.logs) { oldValue, newValue in
                // Update groups when logs change
                updateLocationGroups()
            }
            .onChange(of: selectedLocationGroupID) { oldValue, newValue in
                // When sheet closes (selection becomes nil), refresh map to show updated names
                if newValue == nil {
                    updateLocationGroups()
                    mapRefreshID = UUID()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Creates the sheet content for a location group to simplify complex expressions
    @ViewBuilder
    private func locationGamesSheetContent(for group: LocationGroup) -> some View {
        LocationGamesView(
            locationGroup: group,
            namedLocations: $namedLocations
        )
        .environmentObject(logStore)
        .environmentObject(authViewModel)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    /// Returns the display name for a location group, showing game title for single games.
    private func displayName(for group: LocationGroup) -> String {
        // If there's a custom name, use it
        if let name = group.name {
            return name
        }
        
        // If there's only one game, show the game title
        if group.logs.count == 1, let log = group.logs.first {
            return log.gameTitle ?? "Game \(log.gameId)"
        }
        
        // Multiple games - show location count
        return "Location (\(group.logs.count))"
    }
    
    private func loadNamedLocations() {
        guard let userID = authViewModel.currentUserID else { return }
        isLoadingNamedLocations = true
        
        NamedLocationService.shared.fetchNamedLocations(for: userID) { result in
            DispatchQueue.main.async {
                isLoadingNamedLocations = false
                switch result {
                case .success(let locations):
                    namedLocations = locations
                    updateLocationGroups() // Update groups after loading named locations
                case .failure(let error):
                    print("Error loading named locations: \(error.localizedDescription)")
                    // Non-critical error, continue without named locations
                    updateLocationGroups() // Still update groups even if loading failed
                }
            }
        }
    }
    
    private func updateCameraPosition() {
        // Use current locationGroups state
        let groups = locationGroups
        
        guard !groups.isEmpty else { return }
        
        let coordinates = groups.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }
        
        // Find min/max lat/long
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Calculate span with padding
        let latDelta = max((maxLat - minLat) * 1.5, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.5, 0.01)
        
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        )
    }
}

// MARK: - Location Games View

struct LocationGamesView: View {
    let locationGroup: LocationGroup
    @Binding var namedLocations: [NamedLocation]
    
    @EnvironmentObject var logStore: GameLogStore
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var locationName: String = ""
    @State private var isEditingName: Bool = false
    @State private var isLoading: Bool = false
    
    /// Returns the display name for a location group in the detail view.
    private func locationDisplayName(for group: LocationGroup) -> String {
        // If there's a custom name, use it
        if let name = group.name {
            return name
        }
        
        // If there's only one game, show the game title
        if group.logs.count == 1, let log = group.logs.first {
            return log.gameTitle ?? "Game \(log.gameId)"
        }
        
        // Multiple games - show location
        return "Location"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backlogBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Location header with name
                    VStack(spacing: 12) {
                        if isEditingName {
                            TextField("Location name (e.g., Home)", text: $locationName)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            HStack {
                                Button("Cancel") {
                                    locationName = currentDisplayName
                                    isEditingName = false
                                }
                                .foregroundColor(.backlogSecondary)
                                .disabled(isLoading)
                                
                                Spacer()
                                
                                Button("Save") {
                                    saveLocationName()
                                }
                                .foregroundColor(.backlogAccentRed)
                                .fontWeight(.semibold)
                                .disabled(isLoading || locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.leading, 8)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentDisplayName)
                                        .font(.title2.bold())
                                        .foregroundColor(.backlogPrimary)
                                    
                                    Text("\(locationGroup.gameCount) game\(locationGroup.gameCount == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundColor(.backlogSecondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    locationName = currentDisplayName
                                    isEditingName = true
                                } label: {
                                    Image(systemName: hasCustomName ? "pencil.circle.fill" : "pencil")
                                        .foregroundColor(.backlogAccentRed)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color.backlogCard)
                    
                    // Games list
                    if locationGroup.logs.isEmpty {
                        Spacer()
                        Text("No games at this location")
                            .foregroundColor(.backlogSecondary)
                        Spacer()
                    } else {
                        List {
                            ForEach(locationGroup.logs.sorted(by: { $0.updatedAt > $1.updatedAt })) { log in
                                // Use stored game data from log
                                let game = log.toGame()
                                NavigationLink {
                                    GameReviewView(game: game, log: log)
                                        .environmentObject(logStore)
                                } label: {
                                    LocationGameRow(game: game, log: log)
                                }
                                .listRowBackground(Color.backlogCard)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.backlogBackground)
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                locationName = currentDisplayName
            }
            .onChange(of: namedLocations) { oldValue, newValue in
                // Update the text field when namedLocations changes
                locationName = currentDisplayName
            }
        }
    }
    
    /// Computed property for display name that reads dynamically from namedLocations binding
    private var currentDisplayName: String {
        // Check if there's a named location for this coordinate
        if let namedLocation = namedLocations.first(where: { location in
            location.matches(coordinate: locationGroup.coordinate)
        }) {
            return namedLocation.name
        }
        return locationDisplayName(for: locationGroup)
    }
    
    /// Whether this location has a custom name set
    private var hasCustomName: Bool {
        namedLocations.contains { location in
            location.matches(coordinate: locationGroup.coordinate)
        }
    }
    
    private func saveLocationName() {
        guard let userID = authViewModel.currentUserID else { return }
        guard !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Delete name if empty
            deleteLocationName()
            return
        }
        
        // Create or update named location
        let geoPoint = GeoPoint(
            latitude: locationGroup.coordinate.latitude,
            longitude: locationGroup.coordinate.longitude
        )
        
        // Update UI optimistically FIRST (before Firestore save)
        // This ensures immediate UI feedback
        
        // Check if named location already exists
        if let existingLocation = namedLocations.first(where: { location in
            location.matches(coordinate: locationGroup.coordinate)
        }) {
            var updatedLocation = existingLocation
            updatedLocation.name = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Update UI immediately (optimistic update)
            var updatedLocations = namedLocations
            if let index = updatedLocations.firstIndex(where: { $0.id == existingLocation.id }) {
                updatedLocations[index] = updatedLocation
                namedLocations = updatedLocations
            }
            isEditingName = false
            
            // Save to Firestore silently in background (no loading spinner)
            NamedLocationService.shared.saveNamedLocation(updatedLocation) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Success - UI already updated optimistically
                        break
                    case .failure(let error):
                        print("Error saving location name: \(error.localizedDescription)")
                        // On error, we could show an alert, but for now just log
                        // The optimistic update will remain until user refreshes
                    }
                }
            }
        } else {
            // Create new named location
            let newLocation = NamedLocation(
                userID: userID,
                coordinate: geoPoint,
                name: locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Update UI immediately (optimistic update)
            var updatedLocations = namedLocations
            updatedLocations.append(newLocation)
            namedLocations = updatedLocations
            isEditingName = false
            
            // Save to Firestore silently in background (no loading spinner)
            NamedLocationService.shared.saveNamedLocation(newLocation) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Success - UI already updated optimistically
                        break
                    case .failure(let error):
                        print("Error saving location name: \(error.localizedDescription)")
                        // On error, we could show an alert, but for now just log
                        // The optimistic update will remain until user refreshes
                    }
                }
            }
        }
    }
    
    private func deleteLocationName() {
        guard let existingLocation = namedLocations.first(where: { location in
            location.matches(coordinate: locationGroup.coordinate)
        }) else {
            isEditingName = false
            return
        }
        
        isLoading = true
        
        NamedLocationService.shared.deleteNamedLocation(existingLocation.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    namedLocations.removeAll { $0.id == existingLocation.id }
                    locationName = currentDisplayName
                    isEditingName = false
                case .failure(let error):
                    print("Error deleting location name: \(error.localizedDescription)")
                    // Could show error alert here
                }
            }
        }
    }
}

// MARK: - Location Game Row Views

private struct LocationGameRow: View {
    let game: Game
    let log: GameLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Game cover image
            if let coverURL = game.coverURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.backlogBackground)
                            .frame(width: 50, height: 50)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.backlogAccentRed)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.backlogBackground)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundColor(.backlogSecondary)
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.backlogBackground)
                            .frame(width: 50, height: 50)
                    }
                }
            } else {
                // Placeholder when no cover URL
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backlogBackground)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(.backlogSecondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .foregroundColor(.backlogPrimary)
                
                Text(log.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.backlogSecondary)
                
                if let rating = log.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("\(rating)/10")
                            .font(.caption)
                    }
                    .foregroundColor(.backlogAccentRed)
                }
                
                Text(log.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.backlogTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct LocationGameRowFallback: View {
    let log: GameLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.backlogBackground)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.backlogSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Game ID: \(log.gameId)")
                    .font(.headline)
                    .foregroundColor(.backlogPrimary)
                
                Text(log.status.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.backlogSecondary)
                
                Text(log.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.backlogTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location Game Detail View

private struct LocationGameDetailView: View {
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
                    Text("Review")
                        .font(.headline)
                        .foregroundColor(.backlogPrimary)
                    Text(reviewText)
                        .font(.body)
                        .foregroundColor(.backlogSecondary)
                }
            }
            .padding()
        }
        .navigationTitle("Log Details")
        .background(Color.backlogBackground)
    }
}

#Preview {
    ActivityMapView()
        .environmentObject(GameLogStore())
        .environmentObject(AuthViewModel())
}

