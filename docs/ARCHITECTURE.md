# Focus Sounds — architecture

## Product

Native macOS menu bar app. Plays dev-bundled focus sounds on loop. When other system audio is detected, focus audio ducks to ~10% volume; restores when external audio stops.

## Stack

- Swift 5.9, SwiftUI `MenuBarExtra`
- `AVPlayer` for streaming playback (large mp4 files)
- Core Audio process tap (`CATapDescription(stereoGlobalTapButExcludeProcesses:)`) on macOS 14.2+
- `FocusSoundsCore`: RMS metering + hysteresis ducking state machine + volume fader (unit tested)

## Sound bundling

Drop files in repo-root `Sounds/`. `scripts/build-app.sh` copies them into the app bundle at `Contents/Resources/Sounds/`.

## Permissions

`NSAudioCaptureUsageDescription` in `Sources/FocusSounds/Info.plist`. Tap excludes the app's own process from monitoring.

## Build output

`dist/FocusSounds.app` — `LSUIElement` menu bar app (no Dock icon).
