// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AskFox",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AskFoxCore", targets: ["AskFoxCore"]),
        .executable(name: "AskFox", targets: ["AskFoxApp"]),
        .executable(name: "AskFoxIndex", targets: ["AskFoxIndex"]),
        .executable(name: "AskFoxCoreCheck", targets: ["AskFoxCoreCheck"])
    ],
    targets: [
        .target(name: "AskFoxCore"),
        .executableTarget(
            name: "AskFoxApp",
            dependencies: ["AskFoxCore"]
        ),
        .executableTarget(
            name: "AskFoxIndex",
            dependencies: ["AskFoxCore"]
        ),
        .executableTarget(
            name: "AskFoxCoreCheck",
            dependencies: ["AskFoxCore"]
        )
    ]
)
