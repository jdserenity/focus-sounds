# Focus Sounds

Menu bar Mac app that plays bundled focus audio and automatically ducks it when other apps play sound (Spotify, YouTube, etc.).

## Setup

1. Copy your focus sound files into `Sounds/` (mp3, wav, m4a, mp4, aiff, aac, caf, flac). Large files are fine — playback streams from disk.
2. Build the app bundle:

```bash
./scripts/build-app.sh
open dist/FocusSounds.app
```

3. On first play, macOS asks for **System Audio Recording** permission. Allow it so the app can detect other audio. Nothing is recorded or saved.

## Requirements

- macOS 14.2+ (Core Audio process taps)
- Xcode or Swift toolchain (`swift build`)

Run unit tests (needs full Xcode, not Command Line Tools only):

```bash
swift test
```
