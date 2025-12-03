//
//  UserService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Service layer for user profile operations in Firestore.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service responsible for user profile CRUD operations in Firestore.
final class UserService {
    
    static let shared = UserService()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    private init() {}
    
    /// Creates a user document in Firestore if it doesn't exist.
    ///
    /// - Parameters:
    ///   - userID: Firebase Auth UID
    ///   - displayName: User's display name
    ///   - completion: Called with result (success or error)
    func createUserIfNeeded(userID: String, displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection(usersCollection).document(userID)
        
        userRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // If document doesn't exist, create it
            if document?.exists == false {
                let newUser = User(
                    id: userID,
                    displayName: displayName
                )
                
                userRef.setData(newUser.toDictionary()) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            } else {
                // User already exists
                completion(.success(()))
            }
        }
    }
    
    /// Fetches a user by their ID.
    ///
    /// - Parameters:
    ///   - userID: Firebase Auth UID
    ///   - completion: Called with result (User or error)
    func fetchUser(userID: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection(usersCollection).document(userID).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document,
                  document.exists,
                  let data = document.data(),
                  let user = User(from: data, id: document.documentID) else {
                completion(.failure(NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                return
            }
            
            completion(.success(user))
        }
    }
    
    /// Updates a user's profile information.
    ///
    /// - Parameters:
    ///   - userID: Firebase Auth UID
    ///   - displayName: Optional new display name
    ///   - bio: Optional new bio
    ///   - photoURL: Optional new photo URL
    ///   - completion: Called with result (success or error)
    func updateUser(
        userID: String,
        displayName: String? = nil,
        bio: String? = nil,
        photoURL: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var updates: [String: Any] = [:]
        
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        if let bio = bio {
            updates["bio"] = bio
        }
        if let photoURL = photoURL {
            updates["photoURL"] = photoURL
        }
        
        guard !updates.isEmpty else {
            completion(.success(()))
            return
        }
        
        // Use setData with merge: true to create document if it doesn't exist, or update if it does
        let userRef = db.collection(usersCollection).document(userID)
        
        // First, check if document exists to ensure we have required fields
        userRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            var dataToSet: [String: Any] = updates
            
            // If document doesn't exist, we need to create it with required fields
            if document?.exists == false {
                // Get display name from Firebase Auth
                let displayName = Auth.auth().currentUser?.displayName ?? "User"
                dataToSet["displayName"] = displayName
                dataToSet["followedUserIDs"] = []
                dataToSet["createdAt"] = Timestamp(date: Date())
            }
            
            // Use setData with merge: true - creates if doesn't exist, updates if it does
            userRef.setData(dataToSet, merge: true) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    /// Adds a user to the current user's followed list.
    ///
    /// - Parameters:
    ///   - currentUserID: Current user's UID
    ///   - userIDToFollow: UID of user to follow
    ///   - completion: Called with result (success or error)
    func followUser(currentUserID: String, userIDToFollow: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection(usersCollection).document(currentUserID)
        
        userRef.updateData([
            "followedUserIDs": FieldValue.arrayUnion([userIDToFollow])
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Removes a user from the current user's followed list.
    ///
    /// - Parameters:
    ///   - currentUserID: Current user's UID
    ///   - userIDToUnfollow: UID of user to unfollow
    ///   - completion: Called with result (success or error)
    func unfollowUser(currentUserID: String, userIDToUnfollow: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection(usersCollection).document(currentUserID)
        
        userRef.updateData([
            "followedUserIDs": FieldValue.arrayRemove([userIDToUnfollow])
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

