//
//  LocationService.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Service layer for location services using Core Location.
//  Handles permissions and provides current location.
//

import Foundation
import Combine
import CoreLocation
import FirebaseFirestore

/// Errors that can occur during location operations.
enum LocationServiceError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable
    case locationUpdateFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to attach location to game logs."
        case .locationUnavailable:
            return "Location services are not available on this device."
        case .locationUpdateFailed:
            return "Could not get your current location. Please try again."
        }
    }
}

/// Service responsible for location operations.
final class LocationService: NSObject, ObservableObject {
    
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isUpdatingLocation = false
    
    private var locationCompletion: ((Result<CLLocation, Error>) -> Void)?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Good enough for game logging
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Requests location authorization.
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Gets the current location once.
    ///
    /// - Parameter completion: Called with the location or an error.
    func getCurrentLocation(completion: @escaping (Result<CLLocation, Error>) -> Void) {
        // Check authorization
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            if authorizationStatus == .notDetermined {
                locationCompletion = completion
                requestAuthorization()
                return
            } else {
                completion(.failure(LocationServiceError.permissionDenied))
                return
            }
        }
        
        locationCompletion = completion
        isUpdatingLocation = true
        
        // Check location services asynchronously to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard CLLocationManager.locationServicesEnabled() else {
                DispatchQueue.main.async {
                    self.isUpdatingLocation = false
                    completion(.failure(LocationServiceError.locationUnavailable))
                }
                return
            }
            
            // Request location on main thread (CLLocationManager should be used on main thread)
            DispatchQueue.main.async {
                self.locationManager.requestLocation()
            }
        }
    }
    
    /// Converts CLLocation to Firestore GeoPoint.
    func locationToGeoPoint(_ location: CLLocation) -> GeoPoint {
        return GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    /// Converts Firestore GeoPoint to CLLocationCoordinate2D.
    func geoPointToCoordinate(_ geoPoint: GeoPoint) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        currentLocation = location
        isUpdatingLocation = false
        
        if let completion = locationCompletion {
            completion(.success(location))
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isUpdatingLocation = false
        
        if let completion = locationCompletion {
            completion(.failure(LocationServiceError.locationUpdateFailed))
            locationCompletion = nil
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        // If we were waiting for authorization and now have it, request location
        // Use async to avoid potential main thread blocking
        if (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways),
           let completion = locationCompletion {
            // Small delay to ensure authorization is fully processed
            DispatchQueue.main.async { [weak self] in
                self?.getCurrentLocation(completion: completion)
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted,
                  let completion = locationCompletion {
            completion(.failure(LocationServiceError.permissionDenied))
            locationCompletion = nil
        }
    }
}

