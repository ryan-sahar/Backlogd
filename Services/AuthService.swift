//
//  AuthService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Service layer for Firebase Authentication.
//  Wraps Firebase Auth to provide a clean interface for ViewModels.
//

import Foundation
import FirebaseAuth

/// Service responsible for authentication operations.
///
/// This service wraps Firebase Auth and provides a clean interface
/// that ViewModels can use without directly depending on Firebase types.
final class AuthService {
    
    static let shared = AuthService()
    
    private init() {}
    
    /// The current authenticated user, if any.
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
    
    /// Current user's UID, if authenticated.
    var currentUserID: String? {
        currentUser?.uid
    }
    
    /// Adds a listener for authentication state changes.
    ///
    /// - Parameter handler: Called when auth state changes, with the new user (or nil if signed out).
    /// - Returns: A handle that can be used to remove the listener.
    func addAuthStateListener(_ handler: @escaping (FirebaseAuth.User?) -> Void) -> AuthStateDidChangeListenerHandle {
        return Auth.auth().addStateDidChangeListener { _, user in
            handler(user)
        }
    }
    
    /// Removes an authentication state listener.
    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }
    
    /// Signs in a user with email and password.
    ///
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Called with result (success or error)
    func signIn(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = result?.user {
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])))
            }
        }
    }
    
    /// Creates a new user account with email and password.
    ///
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Called with result (success or error)
    func createUser(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = result?.user {
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])))
            }
        }
    }
    
    /// Updates the current user's display name.
    ///
    /// - Parameters:
    ///   - displayName: New display name
    ///   - completion: Called with result (success or error)
    func updateDisplayName(_ displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser else {
            completion(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])))
            return
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        changeRequest.commitChanges { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Signs out the current user.
    func signOut() throws {
        try Auth.auth().signOut()
    }
}

