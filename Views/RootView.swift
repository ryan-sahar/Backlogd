//
//  RootView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  High-level container that decides which part of the app to show
//  based on authentication state.
//

import SwiftUI

struct RootView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var logStore: GameLogStore
    
    var body: some View {
        ZStack {
            Color.backlogBackground.ignoresSafeArea()
            
            Group {
                if authViewModel.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { oldValue, newValue in
            if newValue, let userID = authViewModel.currentUserID {
                // Start observing logs when user signs in
                logStore.observeLogs(for: userID)
            } else {
                // Stop observing when user signs out
                logStore.stopObserving()
            }
        }
        .onAppear {
            // Handle case where user is already signed in on app launch
            if authViewModel.isAuthenticated, let userID = authViewModel.currentUserID {
                logStore.observeLogs(for: userID)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
        .environmentObject(GameLogStore())
}


