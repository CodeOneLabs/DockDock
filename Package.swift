// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DockDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DockDock", targets: ["DockDock"]),
        .executable(name: "GeometryChecks", targets: ["GeometryChecks"])
    ],
    targets: [
        .target(
            name: "DockDockCore",
            path: "Sources/DockDockCore"
        ),
        .executableTarget(
            name: "DockDock",
            dependencies: ["DockDockCore"],
            path: "Sources/DockDock"
        ),
        .executableTarget(
            name: "GeometryChecks",
            dependencies: ["DockDockCore"],
            path: "Sources/GeometryChecks"
        )
    ]
)
