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
//        .package(url: "https://github.com/sajjon/k1.git", from: "0.6.0"),
        .package(url: "https://github.com/radmakr/K1.git", branch: "rademaker_point_add_subtract")
    ],
    targets: [
        .target(
            name: "CashuKit",
            dependencies: [
                .product(name: "K1", package: "k1"),
            ]
        ),
        .testTarget(
            name: "CashuKitTests",
            dependencies: ["CashuKit"]
        ),
    ]
)
