// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PreStage",
    defaultLocalization: "en",
    platforms: [
        .macOS("15.4")
    ],
    products: [
        .executable(name: "PreStage", targets: ["PreStage"])
    ],
    targets: [
        .executableTarget(
            name: "PreStage",
            path: "Sources/PreStage",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PreStageTests",
            dependencies: ["PreStage"],
            path: "Tests/PreStageTests"
        )
    ]
)
