//
//  ProfileView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  User profile screen showing stats, user info, and settings.
//

import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var logStore: GameLogStore
    
    @StateObject private var viewModel: ProfileViewModel
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showCropView = false
    @State private var imageToCrop: UIImage?
    @State private var croppedImage: UIImage?
    @State private var isUploadingPhoto = false
    @State private var uploadError: String?
    
    init(logStore: GameLogStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(logStore: logStore))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Section
                    statsSection
                    
                    // Settings Section
                    settingsSection
                }
                .padding()
            }
            .overlay {
                // Subtle loading overlay instead of blocking
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.backlogAccentRed)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                if let userID = authViewModel.currentUserID {
                    viewModel.loadUser(userID: userID)
                }
            }
            .alert("Upload Error", isPresented: Binding(
                get: { uploadError != nil },
                set: { if !$0 { uploadError = nil } }
            )) {
                Button("OK") {
                    uploadError = nil
                }
            } message: {
                if let error = uploadError {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Image Upload
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let userID = authViewModel.currentUserID else { return }
        
        isUploadingPhoto = true
        uploadError = nil
        
        // Get the old photo URL before uploading
        let oldPhotoURL = viewModel.user?.photoURL
        
        // First, delete the old image if it exists (don't wait for completion - fire and forget)
        if let oldURL = oldPhotoURL {
            StorageService.shared.deleteProfileImage(urlString: oldURL) { _ in
                // Ignore errors - if it fails, the upload will still proceed
            }
        }
        
        // Upload the new image
        StorageService.shared.uploadProfileImage(image, userID: userID) { (result: Result<String, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let photoURL):
                    // Update user's photoURL in Firestore
                    self.viewModel.updatePhotoURL(photoURL, userID: userID) { (updateResult: Result<Void, Error>) in
                        DispatchQueue.main.async {
                            self.isUploadingPhoto = false
                            switch updateResult {
                            case .success:
                                // Success - user will be reloaded by updatePhotoURL
                                break
                            case .failure(let error):
                                self.uploadError = error.localizedDescription
                            }
                        }
                    }
                case .failure(let error):
                    self.isUploadingPhoto = false
                    self.uploadError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar with tap to edit
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.backlogCard)
                        .frame(width: 100, height: 100)
                    
                    if let photoURL = viewModel.user?.photoURL {
                        AsyncImageLoader(urlString: photoURL)
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.backlogSecondary)
                    }
                    
                    // Edit overlay
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        )
                        .opacity(isUploadingPhoto ? 1 : 0)
                    
                    if isUploadingPhoto {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
            .disabled(isUploadingPhoto)
            
            // Name
            Text(viewModel.user?.displayName ?? authViewModel.userDisplayName)
                .font(.title.bold())
                .foregroundColor(.backlogPrimary)
            
            // Email (if available)
            if let email = authViewModel.currentUserEmail {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.backlogSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showCropView) {
            if let image = imageToCrop {
                ImageCropView(image: image, croppedImage: $croppedImage)
            }
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let newImage = newValue {
                // Image selected from picker - show crop view
                imageToCrop = newImage
                showCropView = true
            }
        }
        .onChange(of: croppedImage) { oldValue, newValue in
            if let cropped = newValue {
                // Image was cropped - upload it
                uploadProfileImage(cropped)
                // Clean up
                imageToCrop = nil
                selectedImage = nil
                croppedImage = nil
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.backlogPrimary)
            
            VStack(spacing: 12) {
                StatRow(
                    icon: "gamecontroller.fill",
                    label: "Games Logged",
                    value: "\(viewModel.totalGamesLogged)"
                )
                
                StatRow(
                    icon: "checkmark.circle.fill",
                    label: "Completed",
                    value: "\(viewModel.completedCount)"
                )
                
                StatRow(
                    icon: "star.fill",
                    label: "Average Rating",
                    value: "\(viewModel.averageRatingString)/10"
                )
                
                if viewModel.totalPlaytimeHours > 0 {
                    StatRow(
                        icon: "clock.fill",
                        label: "Total Playtime",
                        value: viewModel.totalPlaytimeString
                    )
                }
            }
        }
        .padding()
        .background(Color.backlogCard)
        .cornerRadius(16)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.backlogPrimary)
            
            // View Map button
            NavigationLink {
                ActivityMapView()
                    .environmentObject(logStore)
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.backlogAccentRed)
                    Text("View Map")
                        .foregroundColor(.backlogPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.backlogSecondary)
                }
                .padding()
                .background(Color.backlogCard)
                .cornerRadius(12)
            }
            
            Button {
                authViewModel.logout()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.backlogAccentRed)
                    Text("Log Out")
                        .foregroundColor(.backlogAccentRed)
                    Spacer()
                }
                .padding()
                .background(Color.backlogCard)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Stat Row Component

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.backlogAccentRed)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.backlogSecondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(.backlogPrimary)
        }
    }
}

#Preview {
    ProfileView(logStore: GameLogStore())
        .environmentObject(AuthViewModel())
        .environmentObject(GameLogStore())
}

