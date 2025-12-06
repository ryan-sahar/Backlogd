//
//  AuthViewModel.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  View model responsible for handling authentication state.
//  Uses AuthService and UserService to manage authentication and user profiles.
//

import Foundation
import Combine
import FirebaseAuth

/// `AuthViewModel` owns the authentication state for the entire app.
final class AuthViewModel: ObservableObject {
    
    private let authService = AuthService.shared
    private let userService = UserService.shared
    
    /// Whether a user is currently authenticated.
    @Published var isAuthenticated: Bool = false
    
    /// A human-readable authentication error message, if any.
    @Published var authErrorMessage: String?
    
    /// Whether authentication is currently in progress.
    @Published var isLoading: Bool = false
    
    /// The current Firebase user (optional).
    @Published var currentUser: FirebaseAuth.User?
    
    /// Used to keep track of the Firebase auth state listener.
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Init / Deinit
    
    init() {
        // Listen for changes to the Firebase authentication state.
        authStateHandle = authService.addAuthStateListener { [weak self] (user: FirebaseAuth.User?) in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = (user != nil)
            }
        }
    }
    
    deinit {
        // Clean up the listener when this object is deallocated.
        if let handle = authStateHandle {
            authService.removeAuthStateListener(handle)
        }
    }
    
    // MARK: - Public API
    
    /// Attempts to sign in an existing user with email and password.
    func login(email: String, password: String) {
        authErrorMessage = nil
        isLoading = true
        
        authService.signIn(email: email, password: password) { [weak self] (result: Result<FirebaseAuth.User, Error>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    // Auth state listener will update isAuthenticated
                    break
                case .failure(let error):
                    self?.authErrorMessage = Self.userFriendlyErrorMessage(from: error)
                }
            }
        }
    }
    
    /// Attempts to create a new user account, then signs them in.
    func register(displayName: String, email: String, password: String) {
        authErrorMessage = nil
        isLoading = true
        
        authService.createUser(email: email, password: password) { [weak self] (result: Result<FirebaseAuth.User, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    // Update display name in Firebase Auth
                    self?.authService.updateDisplayName(displayName) { (_: Result<Void, Error>) in
                        // Continue even if display name update fails
                    }
                    
                    // Create user document in Firestore
                    self?.userService.createUserIfNeeded(userID: user.uid, displayName: displayName) { (result: Result<Void, Error>) in
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            if case .failure(let error) = result {
                                print("Failed to create user document: \(error.localizedDescription)")
                            }
                    }
                }
                
                    // Auth state listener will handle updating isAuthenticated
                case .failure(let error):
                    self?.isLoading = false
                    self?.authErrorMessage = Self.userFriendlyErrorMessage(from: error)
                }
            }
        }
    }
    
    /// Signs out the current user.
    func logout() {
        do {
            try authService.signOut()
            authErrorMessage = nil
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }
    
    /// A simple display name the UI can use without depending on Firebase types.
    var userDisplayName: String {
        currentUser?.displayName?.isEmpty == false ? (currentUser?.displayName ?? "You") : "You"
    }
    
    /// Current user's UID, if authenticated.
    var currentUserID: String? {
        currentUser?.uid
    }
    
    /// Current user's email address, if authenticated.
    var currentUserEmail: String? {
        currentUser?.email
    }
    
    // MARK: - Error Handling
    
    /// Converts Firebase errors to user-friendly messages.
    private static func userFriendlyErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        
        // Firebase Auth error codes
        switch nsError.code {
        case 17008: // Invalid email
            return "Please enter a valid email address."
        case 17007: // Email already in use
            return "An account with this email already exists. Please sign in instead."
        case 17011: // User not found
            return "No account found with this email. Please check your email or create an account."
        case 17009, 17010: // Wrong password / Invalid credential
            return "Incorrect email or password. Please try again."
        case 17026: // Weak password
            return "Password is too weak. Please use at least 6 characters."
        case 17020: // Network error
            return "Network error. Please check your connection and try again."
        case 17025: // Too many requests
            return "Too many attempts. Please wait a moment and try again."
        default:
            // Return a generic but friendly message for unknown errors
            let errorMessage = nsError.localizedDescription.lowercased()
            if errorMessage.contains("network") || errorMessage.contains("internet") {
                return "Network error. Please check your connection and try again."
            } else if errorMessage.contains("password") {
                return "Password error. Please check your password and try again."
            } else if errorMessage.contains("email") {
                return "Email error. Please check your email address and try again."
            }
            return "Something went wrong. Please try again."
        }
    }
}
