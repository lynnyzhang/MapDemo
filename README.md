# MapDemo

SwiftUI iOS app that shows nearby Google Places on a MapKit map. Built with Swift 6, targeting iOS 18+.

## Demo video and & screenshot
Video:https://github.com/user-attachments/assets/fe9a829c-dac4-4e4b-975b-a9b3d8d49bc5 

Screenshot: <img width="375" height="667" alt="mapdemo_pin_resized" src="https://github.com/user-attachments/assets/784c1de0-8a31-4aad-bf00-4022f1e0f92f" />

## Requirements

- Xcode 16+
- iOS 18+ deployment target
- No dependency managers (zero SPM/CocoaPods/Carthage dependencies)
- No 3rd party library used

## Setup

```bash
open MapDemo.xcodeproj
```

Select an iOS 18+ simulator, then **Cmd+R** to build and run.

## Features

- **Nearby search** — Fetches places from Google Places API (v1 `searchNearby` endpoint) based on the current map viewport
- **Filter by type** — Toolbar picker to filter by restaurant, gas station, lodging, hospital, or all
- **Auto-follow** — Map camera follows the user's location as they walk, with auto-fetch on significant movement (200m filter)
- **Place details** — Tap a marker to see name, phone, website, and address via the iOS 18 detail sheet
- **Location button** — Custom overlay button to re-center on user location
- **Error toasts** — Gray bottom toast with verbose API error messages (includes response body for HTTP errors), auto-dismisses after 3s
- **Event-driven fetch** — Debounced (300ms) fetch triggered by map pan/zoom, serialized via cancellable Task (last-one-wins)

## Configuration

## Architecture

SwiftUI + MVVM. No UIKit.

| Layer | Key files |
|---|---|
| Entry | `MapDemoApp.swift` — `@main` SwiftUI App, `NavigationStack` → `MapView` |
| Views | `MapView.swift` — Map, annotations, filter picker, overlays |
| ViewModel | `MapViewModel.swift` — `@Observable`, `@MainActor`, location + fetch + filtering |
| Models | `Place.swift` — API response models (all optional props), `FilterType.swift` — enum |
| Networking | `NearBySearchAPI.swift` — API call builder, `ServerCommManager.swift` — free `sendRequest()` function, `APIError.swift` |

## Project Structure

```
MapDemo/
├── MapDemoApp.swift           # App entry point
├── Info.plist                 # Location permission: NSLocationWhenInUseUsageDescription
├── Models/
│   ├── Place.swift            # Decodable Place + nested response types
│   └── FilterType.swift       # Enum: all, restaurant, gas_station, lodging, hospital
├── ViewModels/
│   └── MapViewModel.swift     # Observable VM: location, fetch, error handling
├── Views/
│   └── MapView.swift          # SwiftUI Map with markers, controls, overlays
└── Networking/
    ├── NearBySearchAPI.swift  # Google Places v1 request builder
    ├── ServerCommManager.swift# URLSession HTTP client
    └── APIError.swift         # Error types with verbose descriptions
```

## Limitations

- **iOS 18+ only** — Uses SwiftUI `Map`, `Observation`, `NavigationStack`, and `.mapItemDetailSheet(item:)`
- **No tests** — No XCTest target exists
- **Single screen** — No navigation beyond the map view
- **Google Places v1** — Uses the newer `places.googleapis.com/v1/places:searchNearby` endpoint (not the legacy `maps.googleapis.com/maps/api/place/nearbysearch/json`)
