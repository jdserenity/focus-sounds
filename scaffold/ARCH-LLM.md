# Architecture (agent reference)

Architecture overview built for agents. Dense and compact — optimized so an agent can understand the system without grepping the whole codebase.

Confirmed product and system facts only. No open questions. Lessons and pitfalls belong here as short factual notes, or in scaffold/ARCH-HUMAN.md when they are mainly for the maintainer.

Broader stack/product layout: `scaffold/ARCHITECTURE.md`.

## Headphone auto-pause
- While playing, leaving headphones/earbuds → pause. Returning to headphones/earbuds → resume only if that pause was auto-triggered (`HeadphoneAutoPauseController.pausedDueToDisconnect`).
- Headphones classification (`AudioOutputClassifier`): Bluetooth / Bluetooth LE transport, or built-in output data source FourCC `hdpn`. Internal speakers `ispk` and other outputs → `.other` (USB DACs/headsets not special-cased).
- `OutputRouteMonitor` observes `kAudioHardwarePropertyDefaultOutputDevice` + device `kAudioDevicePropertyDataSource` (output scope). `AppModel` applies `.pause`/`.resume` via `pause(manual:)` / `play(manual:)`; manual pause/play and `selectSound` clear the auto-resume flag.
- Unit tests: `Tests/FocusSoundsCoreTests/FocusSoundsCoreTests.swift` (classifier + `HeadphoneAutoPauseController`). `swift test` requires full Xcode; Command Line Tools alone lack XCTest.

## Now Playing / AirPods controls
- While a sound session is loaded, app publishes to `MPNowPlayingInfoCenter` (`playbackState` + title/artist) and handles `MPRemoteCommandCenter` play/pause/toggle so AirPods stem / media keys control Focus Sounds instead of launching Music.
- Presentation rules: `NowPlayingPresentationBuilder` — active while `hasLoadedItem` (playing or paused); inactive after stop/select clears the player. `NowPlayingController` applies MediaPlayer updates; macOS needs explicit `playbackState`.
- Unit tests for presentation builder in `FocusSoundsCoreTests`.
