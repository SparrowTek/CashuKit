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
        .package(url: "https://github.com/SparrowTek/CoreCashu.git", branch: "main"),
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", from: "0.21.1"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.9.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.6.0"),
        .package(url: "https://github.com/bitcoindevkit/bdk-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/SparrowTek/Vault.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CashuKit",
            dependencies: [
                .product(name: "CoreCashu", package: "CoreCashu"),
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "BigInt", package: "BigInt"),
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
