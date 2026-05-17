# HCPilot iOS App Setup

## Prerequisites

- Xcode 15+
- macOS 13+ (Monterey or later)
- Swift 5.9+

## Installation

1. Open the project in Xcode:
```bash
open hcpilot/ios/HCPilotApp.xcodeproj
```

2. Update the bundle identifier in the project settings to a unique identifier.

3. Configure the API endpoint in `APIService.swift`:
```swift
private let baseURL = "https://api.yourdomain.com"
```

4. Connect your iOS device or select a simulator and run:
```bash
# In Xcode
⌘R
```

## Project Structure

```
HCPilotApp/
├── Assets/           # Images, colors, assets
├── Views/            # SwiftUI views
├── ViewModels/       # View models with state
├── Models/           # Data models
├── Services/         # API and external services
├── Utils/            # Utility functions
├── HCPilotApp.swift  # App entry point
└── ContentView.swift # Main content view
```

## Features Implemented

- ✅ Authentication (Login/Logout)
- ✅ Home Dashboard with stats
- ✅ Visit management
- ✅ Stock management
- ✅ Patient management
- ✅ Profile and Settings
- ✅ Route optimization
- ✅ Map integration

## State Management

The app uses SwiftUI's `@StateObject` and `@ObservedObject` for state management, following the MVVM pattern.

## API Service

The app uses Alamofire for network requests. All API calls are handled in `APIService.swift`.

## Local Development

For local development with a local backend:
1. Ensure your backend is running on `http://localhost:8000`
2. Update the `baseURL` in `APIService.swift`
3. For iOS Simulator, use `http://localhost:8000`
4. For real device on same network, use your Mac's IP address

## Testing

Run tests in Xcode:
```bash
⌘U
```

## Distribution

### TestFlight
1. Archive the app: Product → Archive
2. Distribute to TestFlight: Window → Organizer → Distribute App
3. Upload to App Store Connect

### Ad Hoc
1. Archive the app
2. Export for enterprise distribution
3. Share via MDM or direct download

## Dependencies

- Alamofire (~> 5.8)
- Kingfisher (~> 7.0) - Image loading
- SwiftUI-Introspect (~> 0.5) - View introspection
- SwiftData (iOS 17+) - Data persistence
