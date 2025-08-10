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
        // Core Cashu dependency with platform-agnostic protocol logic
        .package(path: "../CoreCashu"),
        // Apple-specific dependencies only
        .package(url: "https://github.com/bitcoindevkit/bdk-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/SparrowTek/Vault.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CashuKit",
            dependencies: [
                .product(name: "CoreCashu", package: "CoreCashu"),
                .product(name: "BitcoinDevKit", package: "bdk-swift"),
                .product(name: "Vault", package: "Vault"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "CashuKitTests",
            dependencies: ["CashuKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
