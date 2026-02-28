// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadLater",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "Reading List",
            targets: ["ReadLater"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "12.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "ReadLater",
            dependencies: [
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
    ]
)
