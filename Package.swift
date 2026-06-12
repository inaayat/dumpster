// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dumpster",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .executableTarget(
            name: "Dumpster",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/Dumpster",
            resources: [
                .copy("Resources/SpaceGrotesk-Regular.ttf"),
                .copy("Resources/SpaceGrotesk-Medium.ttf"),
                .copy("Resources/SpaceGrotesk-Bold.ttf"),
                .copy("Resources/SpaceGrotesk-Light.ttf"),
                .copy("Resources/AppIcon.icns"),
            ]
        ),
    ]
)
