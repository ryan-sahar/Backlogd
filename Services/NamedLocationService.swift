//
//  NamedLocationService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Service for managing named locations (e.g., "Home", "Office").
//

import Foundation
import FirebaseFirestore
import CoreLocation

final class NamedLocationService {
    static let shared = NamedLocationService()
    
    private let db = Firestore.firestore()
    private let locationsCollection = "namedLocations"
    
    private init() {}
    
    /// Fetches all named locations for a user.
    func fetchNamedLocations(for userID: String, completion: @escaping (Result<[NamedLocation], Error>) -> Void) {
        db.collection(locationsCollection)
            .whereField("userID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let locations = documents.compactMap { doc -> NamedLocation? in
                    let data = doc.data()
                    return NamedLocation(from: data, id: doc.documentID)
                }
                
                completion(.success(locations))
            }
    }
    
    /// Saves or updates a named location.
    func saveNamedLocation(_ location: NamedLocation, completion: @escaping (Result<Void, Error>) -> Void) {
        let locationRef = db.collection(locationsCollection).document(location.id)
        locationRef.setData(location.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Deletes a named location.
    func deleteNamedLocation(_ locationID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(locationsCollection).document(locationID).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Finds a named location that matches the given coordinate.
    func findNamedLocation(
        for coordinate: CLLocationCoordinate2D,
        userID: String,
        completion: @escaping (Result<NamedLocation?, Error>) -> Void
    ) {
        fetchNamedLocations(for: userID) { result in
            switch result {
            case .success(let locations):
                // Find the first location that matches
                let matchingLocation = locations.first { location in
                    let locationCoordinate = CLLocationCoordinate2D(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    return location.matches(coordinate: locationCoordinate)
                }
                completion(.success(matchingLocation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

