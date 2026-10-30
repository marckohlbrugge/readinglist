// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ReadingList",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "Reading List",
            targets: ["ReadingList"]
        ),
    ],
    traits: [
        // In-app updates via Sparkle. The Mac App Store build disables it
        // (`--disable-default-traits`), since App Store apps can't self-update.
        .trait(name: "SparkleUpdates"),
        .default(enabledTraits: ["SparkleUpdates"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "12.9.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.10.1"),
    ],
    targets: [
        .executableTarget(
            name: "ReadingList",
            dependencies: [
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(
                    name: "Sparkle",
                    package: "Sparkle",
                    condition: .when(traits: ["SparkleUpdates"])
                ),
            ]
        ),
        .testTarget(
            name: "ReadingListTests",
            dependencies: ["ReadingList"]
        ),
    ]
)
