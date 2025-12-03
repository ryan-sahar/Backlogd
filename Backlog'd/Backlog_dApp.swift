//
//  Backlog_dApp.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Application entry point.
//  Sets up Firebase, global appearance, and injects shared view models.
//

import SwiftUI

@main
struct Backlog_dApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var logStore      = GameLogStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(logStore)
                .preferredColorScheme(.dark)
        }
    }
}


