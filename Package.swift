// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GreenRAM",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GreenRAM", targets: ["GreenRAM"])
    ],
    targets: [
        .target(name: "MacAotoKillCore"),
        .executableTarget(
            name: "GreenRAM",
            dependencies: ["MacAotoKillCore"],
            path: "Sources/MacAotoKill"
        ),
        .testTarget(
            name: "MacAotoKillCoreTests",
            dependencies: ["MacAotoKillCore"]
        )
    ]
)
