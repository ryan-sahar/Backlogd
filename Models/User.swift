//
//  User.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  User model for Firestore storage.
//  Represents a user profile in the Backlog'd app.
//

import Foundation
import FirebaseFirestore

/// Represents a user in the Backlog'd app.
///
/// Stored in Firestore under the "users" collection.
/// The document ID matches the Firebase Auth UID.
struct User: Identifiable, Codable {
    /// Firebase Auth UID (also the Firestore document ID)
    var id: String
    var displayName: String
    var photoURL: String?
    var bio: String?
    /// Array of user IDs that this user follows
    var followedUserIDs: [String]
    var createdAt: Date
    
    /// Convenience initializer
    init(
        id: String,
        displayName: String,
        photoURL: String? = nil,
        bio: String? = nil,
        followedUserIDs: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.photoURL = photoURL
        self.bio = bio
        self.followedUserIDs = followedUserIDs
        self.createdAt = createdAt
    }
}

// MARK: - Firestore Codable Support

extension User {
    /// Initialize from Firestore document
    init?(from dictionary: [String: Any], id: String) {
        guard let displayName = dictionary["displayName"] as? String else {
            return nil
        }
        
        self.id = id
        self.displayName = displayName
        self.photoURL = dictionary["photoURL"] as? String
        self.bio = dictionary["bio"] as? String
        self.followedUserIDs = dictionary["followedUserIDs"] as? [String] ?? []
        
        if let createdAtTimestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "displayName": displayName,
            "followedUserIDs": followedUserIDs,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL
        }
        if let bio = bio {
            dict["bio"] = bio
        }
        
        return dict
    }
}

