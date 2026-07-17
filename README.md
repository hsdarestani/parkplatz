# FREIRAUM

FREIRAUM is a Flutter vertical slice for a German parking-sharing marketplace: drivers enter a destination and time window, compare demo private/commercial spaces, and inspect protected approximate listings.

## Platforms
Flutter Web, Android and iOS share the same Dart UI/domain code. App identifier: `de.freiraum.parking`.

## Prerequisites
Install a stable Flutter SDK with Dart 3, then run `flutter doctor`.

## Install
`flutter pub get`

## Run
- Web: `flutter run -d chrome`
- Android: `flutter run -d android`
- iOS: `flutter run -d ios` (macOS/Xcode required)

## Build Web
`flutter build web --release`

## Visible routes
- `/` launch experience
- `/discover` map-first discovery
- `/search` search results; configure static hosting to fall back all paths to `index.html` so browser refresh works.

## Demo limitations
All spaces, prices, availability and vehicle data are fictional demo data. No reservation, payment, authentication, backend or real gate access occurs. Exact private addresses are stored only as protected internal demo fields and are not shown in discovery/results.

## Map fallback
The app renders a local navigation-instrument city grid underneath markers, so tile/network failure never leaves a blank search experience.

## Reset demo state
Open the profile preview and use **Demo zurücksetzen** in later iterations; the persistence service already clears demo preference keys.
