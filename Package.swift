// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "FocusSounds",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "FocusSounds", targets: ["FocusSounds"]),
  ],
  targets: [
    .target(
      name: "FocusSoundsCore",
      path: "Sources/FocusSoundsCore"
    ),
    .executableTarget(
      name: "FocusSounds",
      dependencies: ["FocusSoundsCore"],
      path: "Sources/FocusSounds",
      exclude: ["Info.plist"],
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "FocusSoundsCoreTests",
      dependencies: ["FocusSoundsCore"],
      path: "Tests/FocusSoundsCoreTests"
    ),
  ]
)
