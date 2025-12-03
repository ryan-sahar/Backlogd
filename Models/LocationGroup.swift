//
//  LocationGroup.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/25/25.
//
//  Represents a group of game logs that were played at the same location.
//  Groups nearby locations together and allows naming them.
//

import Foundation
import CoreLocation
import FirebaseFirestore

/// Represents a group of games played at the same location.
struct LocationGroup: Identifiable {
    var id: String // Unique identifier for this location group
    var coordinate: CLLocationCoordinate2D // Center coordinate of the group
    var name: String? // Optional user-defined name (e.g., "Home", "Office")
    var logs: [GameLog] // All game logs at this location
    var createdAt: Date // When this location was first logged
    
    init(
        id: String = UUID().uuidString,
        coordinate: CLLocationCoordinate2D,
        name: String? = nil,
        logs: [GameLog] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.coordinate = coordinate
        self.name = name
        self.logs = logs
        self.createdAt = createdAt
    }
    
    /// The display name for this location (custom name or default).
    var displayName: String {
        name ?? "Location \(logs.count)"
    }
    
    /// Number of games played at this location.
    var gameCount: Int {
        logs.count
    }
}

// MARK: - Hashable & Equatable Conformance

extension LocationGroup: Hashable {
    static func == (lhs: LocationGroup, rhs: LocationGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Location Grouping Logic

extension LocationGroup {
    /// Groups game logs by proximity.
    /// Logs within `radiusMeters` of each other are grouped together.
    ///
    /// - Parameters:
    ///   - logs: Game logs with location data
    ///   - radiusMeters: Maximum distance (in meters) to consider locations as the same (default: 100m)
    /// - Returns: Array of location groups
    static func groupLogs(_ logs: [GameLog], radiusMeters: Double = 100.0) -> [LocationGroup] {
        let logsWithLocations = logs.filter { $0.location != nil }
        guard !logsWithLocations.isEmpty else { return [] }
        
        var groups: [LocationGroup] = []
        var processedLogIDs = Set<String>()
        
        for log in logsWithLocations {
            // Skip if already processed
            guard !processedLogIDs.contains(log.id),
                  log.location != nil else { continue }
            
            // Use a clustering approach: find all logs within radius, then expand to find all logs
            // within radius of any log in the cluster (transitive closure)
            var clusterLogs: [GameLog] = [log]
            processedLogIDs.insert(log.id)
            var changed = true
            
            // Keep expanding the cluster until no new logs are added
            while changed {
                changed = false
                for clusterLog in clusterLogs {
                    guard let clusterGeoPoint = clusterLog.location else { continue }
                    let clusterLocation = CLLocation(
                        latitude: clusterGeoPoint.latitude,
                        longitude: clusterGeoPoint.longitude
                    )
                    
                    for otherLog in logsWithLocations {
                        guard !processedLogIDs.contains(otherLog.id),
                              let otherGeoPoint = otherLog.location else { continue }
                        
                        let otherLocation = CLLocation(
                            latitude: otherGeoPoint.latitude,
                            longitude: otherGeoPoint.longitude
                        )
                        
                        let distance = clusterLocation.distance(from: otherLocation)
                        
                        if distance <= radiusMeters {
                            clusterLogs.append(otherLog)
                            processedLogIDs.insert(otherLog.id)
                            changed = true
                        }
                    }
                }
            }
            
            // Calculate center coordinate (average of all logs in cluster)
            let avgLat = clusterLogs.compactMap { $0.location?.latitude }.reduce(0, +) / Double(clusterLogs.count)
            let avgLon = clusterLogs.compactMap { $0.location?.longitude }.reduce(0, +) / Double(clusterLogs.count)
            let centerCoordinate = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            
            // Create stable ID based on rounded coordinate (ensures same location = same ID)
            // Round to ~10 meters precision for grouping (4 decimal places ≈ 11 meters)
            let roundedLat = round(avgLat * 10000) / 10000
            let roundedLon = round(avgLon * 10000) / 10000
            let stableID = "location_\(String(format: "%.4f", roundedLat))_\(String(format: "%.4f", roundedLon))"
            
            // Find earliest log date for createdAt
            let earliestDate = clusterLogs.map { $0.createdAt }.min() ?? Date()
            
            let group = LocationGroup(
                id: stableID,
                coordinate: centerCoordinate,
                logs: clusterLogs,
                createdAt: earliestDate
            )
            
            groups.append(group)
        }
        
        return groups
    }
}

// MARK: - Named Location Storage

/// A named location stored in Firestore.
struct NamedLocation: Identifiable, Codable, Equatable {
    var id: String
    var userID: String
    var coordinate: GeoPoint
    var name: String
    var createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        userID: String,
        coordinate: GeoPoint,
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.coordinate = coordinate
        self.name = name
        self.createdAt = createdAt
    }
    
    static func == (lhs: NamedLocation, rhs: NamedLocation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Firestore Support for NamedLocation

extension NamedLocation {
    init?(from dictionary: [String: Any], id: String) {
        guard let userID = dictionary["userID"] as? String,
              let coordinate = dictionary["coordinate"] as? GeoPoint,
              let name = dictionary["name"] as? String else {
            return nil
        }
        
        self.id = id
        self.userID = userID
        self.coordinate = coordinate
        self.name = name
        
        if let createdAtTimestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
    }
    
    func toDictionary() -> [String: Any] {
        [
            "userID": userID,
            "coordinate": coordinate,
            "name": name,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    /// Checks if a coordinate is close enough to this named location (within 100m).
    func matches(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 100.0) -> Bool {
        let location1 = CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2) <= radiusMeters
    }
}

