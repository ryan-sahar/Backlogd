//
//  AppDelegate.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Bridges the SwiftUI App lifecycle with UIKit so we can
//  perform Firebase configuration when the app launches.
//

import UIKit
import FirebaseCore

/// Traditional UIApplicationDelegate used to perform setup
/// tasks when the app starts, such as configuring Firebase.
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Configure Firebase using the info from GoogleService-Info.plist
        FirebaseApp.configure()
        
        return true
    }
}
