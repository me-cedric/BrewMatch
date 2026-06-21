// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BrewMatch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "brewmatch", targets: ["BrewMatch"]),
    ],
    targets: [
        .executableTarget(
            name: "BrewMatch"
        ),
        .testTarget(
            name: "BrewMatchTests",
            dependencies: ["BrewMatch"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
