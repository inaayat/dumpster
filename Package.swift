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
                .copy("Resources/Inter-Regular.ttf"),
                .copy("Resources/Inter-Medium.ttf"),
                .copy("Resources/Inter-SemiBold.ttf"),
                .copy("Resources/Inter-Bold.ttf"),
                .copy("Resources/AppIcon.icns"),
            ]
        ),
    ]
)
