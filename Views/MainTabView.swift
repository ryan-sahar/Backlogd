//
//  MainTabView.swift
//  Backlog'd
//
//  Created by Ryan Sahar on 11/24/25.
//
//  Main application shell with a tab bar.
//  Each tab will become a full feature area later (Feed, Search, Lists, Profile).
//

import SwiftUI

struct MainTabView: View {
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var logStore: GameLogStore
    
    var body: some View {
        ZStack {
            Color.backlogBackground.ignoresSafeArea()
            
            TabView {
                FeedView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                
                LoggedGamesView()
                    .tabItem {
                        Label("Lists", systemImage: "list.bullet.rectangle")
                    }
                
                ProfileView(logStore: logStore)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }
            .tint(.backlogAccentRed)
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(GameLogStore())
}
