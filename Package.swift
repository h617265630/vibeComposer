// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "vibeComposer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "vibeComposer", targets: ["vibeComposer"])
    ],
    targets: [
        .executableTarget(
            name: "vibeComposer",
            path: "Sources/vibeComposer"
        ),
        .testTarget(
            name: "vibeComposerTests",
            dependencies: ["vibeComposer"],
            path: "Tests/vibeComposerTests"
        )
    ]
)
