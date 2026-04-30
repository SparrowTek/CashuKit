// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CashuKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "CashuKit",
            targets: ["CashuKit"]),
    ],
    dependencies: [
//        .package(path: "../CoreCashu"),
        .package(url: "https://github.com/SparrowTek/CoreCashu.git", branch: "main"),
        .package(url: "https://github.com/bitcoindevkit/bdk-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/SparrowTek/Vault.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "CashuKit",
            dependencies: [
                .product(name: "CoreCashu", package: "CoreCashu"),
                .product(name: "BitcoinDevKit", package: "bdk-swift"),
                .product(name: "Vault", package: "Vault"),
            ],
            // Swift 6 language mode (declared below) covers strict concurrency in both
            // debug and release. The earlier `unsafeFlags(..., .when(.debug))` was redundant
            // in debug and skipped enforcement in release.
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "CashuKitTests",
            dependencies: ["CashuKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
