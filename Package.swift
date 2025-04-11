// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "a-monitor",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "macos-notification-icon", targets: ["AMonitor"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AMonitor",
            dependencies: [],
            path: "Sources"
        )
    ]
)
