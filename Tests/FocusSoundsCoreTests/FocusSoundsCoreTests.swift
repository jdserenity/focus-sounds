import XCTest
@testable import FocusSoundsCore

final class FocusSoundsCoreTests: XCTestCase {
  func testRMSOfSilenceIsZero() {
    XCTAssertEqual(RMSMeter.level(from: []), 0)
    XCTAssertEqual(RMSMeter.level(from: [0, 0, 0]), 0)
  }

  func testRMSOfConstantSignal() {
    let level = RMSMeter.level(from: [0.5, 0.5, 0.5, 0.5])
    XCTAssertEqual(level, 0.5, accuracy: 0.0001)
  }

  func testDuckingHoldsBeforeReacting() {
    var controller = DuckingController(duckThreshold: 0.1, unduckThreshold: 0.05, duckHoldMs: 100, unduckHoldMs: 100)

    XCTAssertFalse(controller.update(level: 0.2, nowMs: 0))
    XCTAssertFalse(controller.isDucked)

    XCTAssertTrue(controller.update(level: 0.2, nowMs: 120))
    XCTAssertTrue(controller.isDucked)
  }

  func testDuckingReleasesAfterQuietHold() {
    var controller = DuckingController(duckThreshold: 0.1, unduckThreshold: 0.05, duckHoldMs: 50, unduckHoldMs: 100)
    _ = controller.update(level: 0.2, nowMs: 60)
    XCTAssertTrue(controller.isDucked)

    XCTAssertFalse(controller.update(level: 0.01, nowMs: 80))
    XCTAssertTrue(controller.update(level: 0.01, nowMs: 200))
    XCTAssertFalse(controller.isDucked)
  }

  func testVolumeFaderDucksSmoothly() {
    var fader = VolumeFader(current: 1, duckFadeMs: 100, restoreFadeMs: 100)
    let first = fader.step(baseVolume: 1, isDucked: true, dtMs: 50)
    XCTAssertLessThan(first, 1)
    XCTAssertGreaterThan(first, 0.08)

    _ = fader.step(baseVolume: 1, isDucked: true, dtMs: 50)
    let third = fader.step(baseVolume: 1, isDucked: true, dtMs: 50)
    XCTAssertEqual(third, 0.08, accuracy: 0.01)
  }

  func testVolumeFaderRestoresSmoothly() {
    var fader = VolumeFader(current: 0.08, duckFadeMs: 100, restoreFadeMs: 200)
    let mid = fader.step(baseVolume: 0.8, isDucked: false, dtMs: 100)
    XCTAssertGreaterThan(mid, 0.08)
    XCTAssertLessThan(mid, 0.8)

    _ = fader.step(baseVolume: 0.8, isDucked: false, dtMs: 100)
    let done = fader.step(baseVolume: 0.8, isDucked: false, dtMs: 100)
    XCTAssertEqual(done, 0.8, accuracy: 0.01)
  }

  func testSoundImportClampsDurationToTenMinutes() {
    XCTAssertEqual(SoundImport.clampedDuration(sourceSeconds: 120), 120)
    XCTAssertEqual(SoundImport.clampedDuration(sourceSeconds: 12_000), SoundImport.maxDurationSeconds)
    XCTAssertEqual(SoundImport.clampedDuration(sourceSeconds: -5), 0)
  }

  func testSoundImportSanitizesFilenames() {
    XCTAssertEqual(
      SoundImport.sanitizedBaseName(from: "Forest Sounds _ Woodland Ambience, Bird Song.mp4"),
      "forest-sounds-woodland-ambience-bird-song"
    )
    XCTAssertEqual(SoundImport.outputFilename(baseName: "My Loop!!!.mp4"), "my-loop.m4a")
  }

  func testSoundImportDeduplicatesOutputNames() {
    let existing = ["forest.m4a", "forest-2.m4a"]
    XCTAssertEqual(SoundImport.deduplicatedFilename(baseName: "Forest", existingFilenames: existing), "forest-3.m4a")
    XCTAssertEqual(SoundImport.deduplicatedFilename(baseName: "Rain", existingFilenames: ["other.m4a"]), "rain.m4a")
  }

  func testSoundImportDisplayTitle() {
    XCTAssertEqual(
      SoundImport.displayTitle(fromFilename: "forest-sounds.m4a"),
      "forest sounds"
    )
  }

  func testSoundImportDetectsFileInsideDirectory() {
    let dir = URL(fileURLWithPath: "/tmp/FocusSounds/Sounds", isDirectory: true)
    let file = dir.appendingPathComponent("rain.m4a")
    let outside = URL(fileURLWithPath: "/tmp/other/rain.m4a")
    XCTAssertTrue(SoundImport.isContainedIn(directory: dir, file: file))
    XCTAssertFalse(SoundImport.isContainedIn(directory: dir, file: outside))
  }
}
