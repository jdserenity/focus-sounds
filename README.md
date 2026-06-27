# Focus Sounds

Menu bar Mac app that plays bundled focus audio and automatically ducks it when other apps play sound (Spotify, YouTube, etc.).

## Setup

1. Build the app bundle:

```bash
./scripts/build-app.sh
open dist/FocusSounds.app
```

2. Click **Import…** in the menu bar window and pick a video or audio file. The app converts it to audio-only M4A and trims to 10 minutes (good for loop sources from YouTube etc.).

3. On first play, macOS asks for **System Audio Recording** permission. Allow it so the app can detect other audio. Nothing is recorded or saved.

## Requirements

- macOS 14.2+ (Core Audio process taps)
- Xcode or Swift toolchain (`swift build`)

Run unit tests (needs full Xcode, not Command Line Tools only):

```bash
swift test
```
