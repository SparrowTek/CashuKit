// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CashuKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", from: "0.21.1")
    ],
    targets: [
        .target(
            name: "CashuKit",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
            ]
        ),
        .testTarget(
            name: "CashuKitTests",
            dependencies: ["CashuKit"]
        ),
    ]
)
