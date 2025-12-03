# Setup Instructions

## Required Files (Not Committed to Git)

For security, these files are **not** included in the repository. You need to add them locally:

### 1. Firebase Configuration (`GoogleService-Info.plist`)
- Download from your Firebase Console
- Place it in: `Backlog'd/GoogleService-Info.plist`
- This file contains your Firebase project credentials

### 2. API Keys (`Services/APIKeys.swift`)
- Copy `Services/APIKeys.swift.example` (if it exists) or create it from scratch
- Add your RAWG API key:
  ```swift
  static let rawg = "YOUR_ACTUAL_RAWG_API_KEY"
  ```

## Initial Setup

1. Clone this repository
2. Add `GoogleService-Info.plist` to the project (see above)
3. Update `Services/APIKeys.swift` with your API keys
4. Open `Backlog'd.xcodeproj` in Xcode
5. Build and run!

**Note**: These sensitive files are in `.gitignore` to protect your credentials and prevent accidental commits.

