//
//  StorageService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Service for handling Firebase Storage operations, particularly image uploads.
//

import Foundation
import FirebaseStorage
import UIKit

enum StorageServiceError: Error, LocalizedError {
    case invalidImage
    case uploadFailed
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image is invalid."
        case .uploadFailed:
            return "Failed to upload image. Please try again."
        case .invalidURL:
            return "Could not retrieve image URL after upload."
        }
    }
}

/// Service responsible for uploading images to Firebase Storage.
final class StorageService {
    
    static let shared = StorageService()
    
    private let storage = Storage.storage()
    private let profileImagesFolder = "profile_images"
    
    private init() {}
    
    /// Uploads a profile image for a user.
    ///
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - userID: Firebase Auth UID (used for file naming)
    ///   - completion: Called with result (download URL string or error)
    func uploadProfileImage(_ image: UIImage, userID: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Compress image to reduce upload size (max 1MB)
        guard let imageData = compressImage(image, maxSizeKB: 1024) else {
            completion(.failure(StorageServiceError.invalidImage))
            return
        }
        
        // Create unique filename: userID_timestamp.jpg
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(userID)_\(timestamp).jpg"
        let storageRef = storage.reference().child("\(profileImagesFolder)/\(filename)")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload image
        print("📤 StorageService: Uploading image to \(storageRef.fullPath)")
        storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ StorageService: Upload failed - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ StorageService: Image uploaded, getting download URL...")
            // Get download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ StorageService: Failed to get download URL - \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let urlString = url?.absoluteString else {
                    print("❌ StorageService: Download URL is nil")
                    completion(.failure(StorageServiceError.invalidURL))
                    return
                }
                
                print("✅ StorageService: Got download URL: \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    /// Deletes a profile image from Storage.
    /// Gracefully handles the case where the file doesn't exist.
    ///
    /// - Parameters:
    ///   - urlString: Full URL string of the image to delete
    ///   - completion: Called with result (success or error)
    func deleteProfileImage(urlString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard URL(string: urlString) != nil else {
            completion(.failure(StorageServiceError.invalidURL))
            return
        }
        
        let storageRef = storage.reference(forURL: urlString)
        
        // Try to delete directly - if file doesn't exist, we'll handle it gracefully
        storageRef.delete { error in
            if let error = error {
                let nsError = error as NSError
                let errorDescription = nsError.localizedDescription.lowercased()
                
                // Check if the error is because the file doesn't exist
                // Firebase Storage error codes: -13010 = object not found
                let isNotFoundError = (nsError.domain == "FIRStorageErrorDomain" && nsError.code == -13010) ||
                                      errorDescription.contains("does not exist") ||
                                      errorDescription.contains("not found") ||
                                      errorDescription.contains("no such file")
                
                if isNotFoundError {
                    // File doesn't exist - that's fine, treat as success
                    completion(.success(()))
                } else {
                    // Real error occurred
                    completion(.failure(error))
                }
            } else {
                // Successfully deleted
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Compresses a UIImage to JPEG data with a maximum file size.
    ///
    /// - Parameters:
    ///   - image: UIImage to compress
    ///   - maxSizeKB: Maximum file size in kilobytes
    /// - Returns: Compressed JPEG data, or nil if compression fails
    private func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data? {
        var compression: CGFloat = 0.8
        let maxBytes = maxSizeKB * 1024
        
        guard var imageData = image.jpegData(compressionQuality: compression) else {
            return nil
        }
        
        // Reduce quality until we're under the max size
        while imageData.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            guard let compressedData = image.jpegData(compressionQuality: compression) else {
                return imageData // Return last valid data
            }
            imageData = compressedData
        }
        
        return imageData
    }
}

