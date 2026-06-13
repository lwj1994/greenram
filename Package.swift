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
    dependencies: [
        .package(url: "https://github.com/lwj1994/apple_view_model.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "MacAotoKillCore"),
        .executableTarget(
            name: "GreenRAM",
            dependencies: [
                "MacAotoKillCore",
                .product(name: "AppleViewModel", package: "apple_view_model")
            ],
            path: "Sources/MacAotoKill"
        ),
        .testTarget(
            name: "MacAotoKillCoreTests",
            dependencies: ["MacAotoKillCore"]
        )
    ]
)
