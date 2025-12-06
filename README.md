# Backlog'd

An iOS app for tracking your game backlog. Search for games, log your play status, rate games, write reviews, and track where you played them.

## Features

- 🔐 **Authentication**: Email/password authentication with Firebase
- 🔍 **Game Search**: Search for games using the RAWG API with voice search support
- 📝 **Game Logging**: Log games with status, rating, review, and playtime
- 📍 **Location Tracking**: Attach location to game logs and view them on a map
- 📊 **Statistics**: View your gaming statistics and progress
- 🗺️ **Map View**: See where you've played games with location grouping
- 📸 **Profile Pictures**: Upload and manage your profile picture
- 🎤 **Voice Search**: Use voice commands to search for games
- 📤 **Sharing**: Share your game reviews and lists

## Tech Stack

- **SwiftUI**: Modern iOS UI framework
- **Firebase**: Authentication, Firestore, and Storage
- **RAWG API**: Game data and metadata
- **Core Location & MapKit**: Location tracking and maps
- **Speech Framework**: Voice search functionality
- **MVVM Architecture**: Clean separation of concerns

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Firebase account
- RAWG API key

## Setup

See [SETUP.md](SETUP.md) for detailed setup instructions.

**Quick Start:**
1. Clone this repository
2. Add your Firebase `GoogleService-Info.plist` to the project (see SETUP.md)
3. Add your RAWG API key to `Services/APIKeys.swift`
4. Open `Backlog'd.xcodeproj` in Xcode
5. Build and run!

**⚠️ Important**: Sensitive files (`GoogleService-Info.plist` and `APIKeys.swift`) are excluded from version control for security.


## License

This project is part of a class assignment.

