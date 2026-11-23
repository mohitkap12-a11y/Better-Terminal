// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BetterTerminal",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BetterTerminalCore", targets: ["BetterTerminalCore"])
    ],
    targets: [
        // Pure-Foundation logic: layouts, workspaces, history, persistence. No UI.
        .target(name: "BetterTerminalCore"),
        .testTarget(name: "BetterTerminalCoreTests", dependencies: ["BetterTerminalCore"])
    ]
)
